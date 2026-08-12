//
//  claude-summarize.swift — Summarize the selected text with Anthropic's
//  Messages API.
//
//  This was a PopClip `javascript file` action until the result moved into a
//  native window: PopClip's JavaScript environment has no subprocess API, so a
//  JS action cannot launch the viewer. As a shell-script action it can, and the
//  API key still arrives from the Keychain-backed `secret` option as
//  $POPCLIP_OPTION_APIKEY.
//
//  Contract: the summary goes to stdout; errors go to stderr. Exit 0 on
//  success, 2 to send the user to the extension settings, 1 otherwise.
//

import Foundation

let apiURL = URL(string: "https://api.anthropic.com/v1/messages")!
let apiVersion = "2023-06-01"
let maxTokens = 1024
let requestTimeout: TimeInterval = 60

// Claude models have a 200K-token context (~800K characters). Stay well inside
// it so a runaway selection fails fast and locally instead of burning a round trip.
let maxInputCharacters = 400_000

// MARK: - Process plumbing

/// Write a message to stderr and exit. `settings: true` (exit code 2) makes
/// PopClip open this extension's settings pane.
func fail(_ message: String, settings: Bool = false) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(settings ? 2 : 1)
}

let environment = ProcessInfo.processInfo.environment

func option(_ name: String) -> String {
    (environment["POPCLIP_OPTION_\(name)"] ?? "")
        .trimmingCharacters(in: .whitespacesAndNewlines)
}

let selectedText = (environment["POPCLIP_TEXT"] ?? "")
    .trimmingCharacters(in: .whitespacesAndNewlines)
let apiKey = option("APIKEY")

guard !apiKey.isEmpty else {
    fail(
        "Add your Anthropic API key in the AI Summarize settings.",
        settings: true
    )
}
guard !selectedText.isEmpty else {
    fail("There is no text to summarize.")
}
guard selectedText.count <= maxInputCharacters else {
    fail(
        "Selection is too long to summarize (\(selectedText.count) characters, limit \(maxInputCharacters))."
    )
}

let model = option("CUSTOMMODEL").isEmpty
    ? (option("MODEL").isEmpty ? "claude-haiku-4-5" : option("MODEL"))
    : option("CUSTOMMODEL")

// MARK: - Prompt

let styleInstruction: String
switch option("STYLE") {
case "bullets":
    styleInstruction =
        "Summarize as 3-6 bullet points, one line each, using '- ' as the bullet marker."
case "tldr":
    styleInstruction = "Write a single-sentence TL;DR of no more than 25 words."
default:
    styleInstruction = "Write a summary of no more than 40 words."
}

// Word budgets, not sentence counts. Measured over 80 runs across both engines:
// a word cap took Claude from 63% of source length down to 35%, while "no more
// than 3 sentences" was violated in 31 of 40 runs and, on the on-device model,
// pushed verbatim copying up (64% -> 85%) as it padded to hit the shape. The
// rewrite clause is what suppresses copying: 10% -> 0% on Claude, 64% -> 34%
// on-device. Keep this block identical to the one in apple-intelligence.swift.
var instructionLines = [
    "You are a summarization engine.",
    styleInstruction,
    "Do not reuse whole sentences from the source; rewrite in your own words.",
    "Keep only load-bearing facts: who, what, when, and any figures.",
    "Drop background, asides, and repetition.",
    "Reply with the summary only: no preamble, no heading, no commentary, and no surrounding quotation marks.",
]
let extraInstructions = option("EXTRA")
if !extraInstructions.isEmpty {
    instructionLines.append(extraInstructions)
}

// MARK: - Request

var request = URLRequest(url: apiURL, timeoutInterval: requestTimeout)
request.httpMethod = "POST"
request.setValue("application/json", forHTTPHeaderField: "content-type")
request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
request.setValue(apiVersion, forHTTPHeaderField: "anthropic-version")

let payload: [String: Any] = [
    "model": model,
    "max_tokens": maxTokens,
    "system": instructionLines.joined(separator: " "),
    "messages": [["role": "user", "content": selectedText]],
]

do {
    request.httpBody = try JSONSerialization.data(withJSONObject: payload)
} catch {
    fail("Could not encode the request: \(error.localizedDescription)")
}

let data: Data
let response: URLResponse
do {
    (data, response) = try await URLSession.shared.data(for: request)
} catch {
    fail(
        "Could not reach the Anthropic API. Check your internet connection. (\(error.localizedDescription))"
    )
}

let body = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
let status = (response as? HTTPURLResponse)?.statusCode ?? 0

// MARK: - Response

/// The `error.message` field of an API error response, if there is one.
func apiMessage() -> String {
    ((body["error"] as? [String: Any])?["message"] as? String) ?? ""
}

guard status == 200 else {
    switch status {
    case 401, 403:
        fail(
            "Anthropic rejected the API key (HTTP \(status)). \(apiMessage())",
            settings: true
        )
    case 404:
        fail(
            "Unknown model '\(model)'. Check the Model / Custom Model setting. \(apiMessage())",
            settings: true
        )
    case 429:
        fail("Rate limited by Anthropic. Wait a moment and try again.")
    case 500...599:
        fail("Anthropic is having trouble (HTTP \(status)). Try again shortly.")
    default:
        fail("Anthropic API error (HTTP \(status)). \(apiMessage())")
    }
}

let blocks = body["content"] as? [[String: Any]] ?? []
var summary = blocks
    .filter { $0["type"] as? String == "text" }
    .compactMap { $0["text"] as? String }
    .joined()
    .trimmingCharacters(in: .whitespacesAndNewlines)

guard !summary.isEmpty else {
    fail("Claude returned an empty summary.")
}

if body["stop_reason"] as? String == "max_tokens" {
    // The summary is usable but was cut short; say so rather than pretend.
    summary += "\n\n[truncated at \(maxTokens) tokens]"
}

print(summary, terminator: "")

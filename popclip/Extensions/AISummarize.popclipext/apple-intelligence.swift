#!/usr/bin/env swift
//
//  apple-intelligence.swift — Summarize the selected text on-device.
//
//  Uses Apple's Foundation Models framework (macOS 26+, Apple silicon, Apple
//  Intelligence enabled). Nothing leaves the machine and there is no API key.
//
//  PopClip contract: the selected text arrives as $POPCLIP_TEXT and settings as
//  $POPCLIP_OPTION_<IDENTIFIER>. stdout is the result (consumed by
//  `after: preview-result`); stderr is the error shown on failure. Exit 0 on
//  success, 2 to send the user to the extension settings, non-zero otherwise.
//

import Foundation

// MARK: - Process plumbing

/// Write a message to stderr and exit. `settings: true` (exit code 2) makes
/// PopClip open this extension's settings pane.
func fail(_ message: String, settings: Bool = false) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(settings ? 2 : 1)
}

let environment = ProcessInfo.processInfo.environment
let selectedText = (environment["POPCLIP_TEXT"] ?? "")
    .trimmingCharacters(in: .whitespacesAndNewlines)
let style = environment["POPCLIP_OPTION_STYLE"] ?? "concise"
let extraInstructions = (environment["POPCLIP_OPTION_EXTRA"] ?? "")
    .trimmingCharacters(in: .whitespacesAndNewlines)

guard !selectedText.isEmpty else {
    fail("There is no text to summarize.")
}

// The on-device model has a small context window (4K tokens on macOS 26). Cap
// the input at roughly a quarter of that in characters, leaving room for the
// instructions and the generated summary.
let maxInputCharacters = 6000

var promptText = selectedText
if promptText.count > maxInputCharacters {
    promptText = String(promptText.prefix(maxInputCharacters))
    FileHandle.standardError.write(
        Data("note: input truncated to \(maxInputCharacters) characters\n".utf8)
    )
}

let styleInstruction: String
switch style {
case "bullets":
    styleInstruction =
        "Summarize as 3-6 bullet points, one line each, using '- ' as the bullet marker."
case "tldr":
    styleInstruction = "Write a single-sentence TL;DR of no more than 25 words."
default:
    styleInstruction = "Write a summary of no more than 40 words."
}

// Word budgets, not sentence counts. Measured over 80 runs across both engines:
// a word cap took the on-device model from 71% of source length down to 25%,
// while "no more than 3 sentences" was violated in 31 of 40 runs and actually
// pushed verbatim copying up (64% -> 85%) as the model padded to hit the shape.
// The rewrite clause is what suppresses copying: 64% -> 34% on-device, 10% -> 0%
// on Claude. Keep this block identical to the one in claude-summarize.swift.
var instructionLines = [
    "You are a summarization engine.",
    styleInstruction,
    "Do not reuse whole sentences from the source; rewrite in your own words.",
    "Keep only load-bearing facts: who, what, when, and any figures.",
    "Drop background, asides, and repetition.",
    "Reply with the summary only: no preamble, no heading, no commentary.",
]
if !extraInstructions.isEmpty {
    instructionLines.append(extraInstructions)
}
let instructions = instructionLines.joined(separator: " ")

// MARK: - Generation

#if canImport(FoundationModels)

    import FoundationModels

    guard #available(macOS 26.0, *) else {
        fail("Apple Intelligence summarization requires macOS 26 or later.")
    }

    switch SystemLanguageModel.default.availability {
    case .available:
        break
    case .unavailable(.deviceNotEligible):
        fail(
            "This Mac does not support Apple Intelligence. Use the Claude action instead, or turn off the Apple Intelligence action in the extension settings."
        )
    case .unavailable(.appleIntelligenceNotEnabled):
        fail(
            "Apple Intelligence is turned off. Enable it in System Settings › Apple Intelligence & Siri.",
            settings: false
        )
    case .unavailable(.modelNotReady):
        fail(
            "The on-device model is still downloading or preparing. Try again in a few minutes."
        )
    case .unavailable(let reason):
        fail("Apple Intelligence is unavailable (\(reason)).")
    }

    do {
        let session = LanguageModelSession(instructions: instructions)
        let response = try await session.respond(to: promptText)

        let summary = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !summary.isEmpty else {
            fail("The on-device model returned an empty summary.")
        }

        // stdout is the action's result — no trailing newline.
        print(summary, terminator: "")
    } catch let error as LanguageModelSession.GenerationError {
        switch error {
        case .exceededContextWindowSize:
            fail("Selection is too long for the on-device model. Select less text.")
        case .guardrailViolation:
            fail("Apple Intelligence declined to summarize this text.")
        case .unsupportedLanguageOrLocale:
            fail("Apple Intelligence does not support this language yet.")
        default:
            fail("On-device summarization failed: \(error.localizedDescription)")
        }
    } catch {
        fail("On-device summarization failed: \(error.localizedDescription)")
    }

#else

    fail(
        "This Mac's toolchain has no FoundationModels framework. Apple Intelligence summarization requires macOS 26 or later."
    )

#endif

#!/usr/bin/env swift
//
//  summary-window.swift — Show a summary in a native floating panel, or as
//  full-screen large type.
//
//  Reads the body text from stdin. Runs its own AppKit run loop until the
//  window is closed, so it must be launched detached from the PopClip action.
//
//  Usage: summary-window --title "Claude · Sonnet 5" [--style panel|fullscreen]
//         < summary.txt
//
//  The full-screen style replaces PopClip's own Large Type, which is reachable
//  only from a `javascript file` action — and JavaScript cannot launch this
//  program in the first place. Drawing it here costs one window and buys
//  control over the typography.
//

import AppKit

// MARK: - Input

enum Style: String {
    case panel
    case fullscreen
}

var windowTitle = "Summary"
var style = Style.panel
var arguments = Array(CommandLine.arguments.dropFirst())
while let flag = arguments.first {
    arguments.removeFirst()
    switch flag {
    case "--title":
        if let value = arguments.first {
            windowTitle = value
            arguments.removeFirst()
        }
    case "--style":
        if let value = arguments.first {
            style = Style(rawValue: value) ?? .panel
            arguments.removeFirst()
        }
    default:
        break
    }
}

let body = String(data: FileHandle.standardInput.readDataToEndOfFile(), encoding: .utf8)?
    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

guard !body.isEmpty else { exit(1) }

// MARK: - Metrics

enum Metrics {
    static let windowWidth: CGFloat = 520
    static let textInset = NSSize(width: 18, height: 14)
    static let titlebarHeight: CGFloat = 28
    static let footerHeight: CGFloat = 38
    static let minTextHeight: CGFloat = 44
    static let maxTextHeight: CGFloat = 460
    static let font = NSFont.systemFont(ofSize: NSFont.systemFontSize + 1)
}

/// Lay the text out off-screen to size a window, or a font, to its content.
func measureTextHeight(
    _ text: String,
    width: CGFloat,
    font: NSFont = Metrics.font,
    alignment: NSTextAlignment = .natural
) -> CGFloat {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = alignment
    paragraph.lineHeightMultiple = 1.15

    let storage = NSTextStorage(
        string: text,
        attributes: [.font: font, .paragraphStyle: paragraph]
    )
    let container = NSTextContainer(
        size: NSSize(width: width, height: .greatestFiniteMagnitude)
    )
    container.lineFragmentPadding = 5  // NSTextView's default
    let layout = NSLayoutManager()
    layout.addTextContainer(container)
    storage.addLayoutManager(layout)
    layout.ensureLayout(for: container)
    return ceil(layout.usedRect(for: container).height)
}

/// The paragraph style both presentations lay text out with. Kept identical to
/// the one `measureTextHeight` measures, or the fitted sizes come out wrong.
func paragraphStyle(alignment: NSTextAlignment) -> NSMutableParagraphStyle {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = alignment
    paragraph.lineHeightMultiple = 1.15
    return paragraph
}

// MARK: - Panel

/// A utility panel still needs key focus so ⌘C, text selection and Esc work.
final class SummaryPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

final class Controller: NSObject, NSWindowDelegate {
    let panel: SummaryPanel
    private let textView: NSTextView
    private let copyButton: NSButton
    private let body: String

    init(title: String, body: String) {
        self.body = body

        let textWidth = Metrics.windowWidth - Metrics.textInset.width * 2
        let textHeight = min(
            max(measureTextHeight(body, width: textWidth), Metrics.minTextHeight),
            Metrics.maxTextHeight
        )
        let contentHeight =
            textHeight + Metrics.textInset.height * 2
            + Metrics.titlebarHeight + Metrics.footerHeight

        textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.textContainerInset = Metrics.textInset
        textView.font = Metrics.font
        textView.textColor = .labelColor
        // Set the attributes on the storage rather than via `string =`, which
        // would take the typing attributes and drop the paragraph style the
        // height was measured with.
        textView.textStorage?.setAttributedString(
            NSAttributedString(
                string: body,
                attributes: [
                    .font: Metrics.font,
                    .paragraphStyle: paragraphStyle(alignment: .natural),
                    .foregroundColor: NSColor.labelColor,
                ]
            )
        )
        textView.isAutomaticLinkDetectionEnabled = true
        textView.checkTextInDocument(nil)

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.autohidesScrollers = true
        scrollView.documentView = textView

        copyButton = NSButton(title: "Copy", target: nil, action: nil)
        copyButton.bezelStyle = .rounded
        copyButton.keyEquivalent = "\r"

        let closeButton = NSButton(title: "Close", target: nil, action: nil)
        closeButton.bezelStyle = .rounded

        panel = SummaryPanel(
            contentRect: NSRect(
                x: 0, y: 0, width: Metrics.windowWidth, height: contentHeight),
            styleMask: [.titled, .closable, .resizable, .utilityWindow, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.title = title
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.animationBehavior = .utilityWindow
        panel.minSize = NSSize(width: 320, height: 140)

        // Vibrant material behind the text — this is what makes it read as a
        // real macOS popover rather than a plain grey box.
        let background = NSVisualEffectView()
        background.material = .popover
        background.blendingMode = .behindWindow
        background.state = .active
        panel.contentView = background

        let footer = NSStackView(views: [closeButton, copyButton])
        footer.orientation = .horizontal
        footer.spacing = 8

        for view in [scrollView, footer] as [NSView] {
            view.translatesAutoresizingMaskIntoConstraints = false
            background.addSubview(view)
        }

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: background.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: background.trailingAnchor),
            scrollView.topAnchor.constraint(
                equalTo: background.topAnchor, constant: Metrics.titlebarHeight),
            scrollView.bottomAnchor.constraint(
                equalTo: footer.topAnchor, constant: -6),

            footer.trailingAnchor.constraint(
                equalTo: background.trailingAnchor, constant: -14),
            footer.bottomAnchor.constraint(
                equalTo: background.bottomAnchor, constant: -10),
        ])

        super.init()

        copyButton.target = self
        copyButton.action = #selector(copyAndClose)
        closeButton.target = self
        closeButton.action = #selector(closePanel)
        panel.delegate = self
        positionNearCursor()
    }

    /// Put the panel under the pointer, nudged to stay fully on its screen.
    private func positionNearCursor() {
        let mouse = NSEvent.mouseLocation
        let screen =
            NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        guard let visible = screen?.visibleFrame else {
            panel.center()
            return
        }

        let size = panel.frame.size
        var origin = NSPoint(x: mouse.x - size.width / 2, y: mouse.y - size.height - 18)
        origin.x = min(max(origin.x, visible.minX + 12), visible.maxX - size.width - 12)
        if origin.y < visible.minY + 12 {
            origin.y = mouse.y + 18  // no room below the pointer; flip above it
        }
        origin.y = min(origin.y, visible.maxY - size.height - 12)
        panel.setFrameOrigin(origin)
    }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    @objc private func copyAndClose() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(body, forType: .string)
        panel.close()
    }

    @objc func closePanel() {
        panel.close()
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.terminate(nil)
    }
}

// MARK: - Full screen

/// Borderless and above the menu bar, so it needs to ask for key focus itself.
final class FullScreenWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

final class FullScreenController: NSObject, NSWindowDelegate {
    let window: FullScreenWindow

    /// The largest size in `range` that still fits the text in `size`.
    /// Large type is only worth it if the text actually gets large, so this
    /// scales up to fill the screen rather than picking one fixed size.
    private static func fittedFontSize(
        for text: String, in size: NSSize, range: ClosedRange<CGFloat>
    ) -> CGFloat {
        var low = range.lowerBound
        var high = range.upperBound
        // Twelve halvings of a ~100pt range settle well inside a tenth of a
        // point — far past what anyone can see, and still instant.
        for _ in 0..<12 {
            let candidate = (low + high) / 2
            let height = measureTextHeight(
                text,
                width: size.width,
                font: .systemFont(ofSize: candidate, weight: .medium),
                alignment: .center
            )
            if height <= size.height {
                low = candidate
            } else {
                high = candidate
            }
        }
        return low
    }

    init(body: String) {
        // The screen under the pointer, not NSScreen.main: `main` is the screen
        // holding the key window, which for a just-launched accessory process
        // is whatever the user was last focused on — the wrong display as often
        // as not. The panel style picks its screen the same way.
        let mouse = NSEvent.mouseLocation
        let screen =
            NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) }
            ?? NSScreen.main ?? NSScreen.screens[0]
        let frame = screen.frame

        // Generous margins: full-bleed text is what makes a full-screen overlay
        // feel like a wall of characters instead of a display.
        let inset = NSSize(width: frame.width * 0.09, height: frame.height * 0.12)
        let available = NSSize(
            width: frame.width - inset.width * 2,
            height: frame.height - inset.height * 2
        )
        let fontSize = Self.fittedFontSize(
            for: body, in: available, range: 16...(frame.height * 0.16)
        )
        let font = NSFont.systemFont(ofSize: fontSize, weight: .medium)
        let textHeight = measureTextHeight(
            body, width: available.width, font: font, alignment: .center
        )

        window = FullScreenWindow(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .screenSaver  // above the menu bar and the Dock
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.animationBehavior = .none
        window.ignoresMouseEvents = false

        let background = NSVisualEffectView(frame: frame)
        background.material = .hudWindow
        background.blendingMode = .behindWindow
        background.state = .active
        background.autoresizingMask = [.width, .height]
        window.contentView = background

        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.textContainerInset = .zero
        textView.textContainer?.lineFragmentPadding = 5
        textView.textStorage?.setAttributedString(
            NSAttributedString(
                string: body,
                attributes: [
                    .font: font,
                    .paragraphStyle: paragraphStyle(alignment: .center),
                    .foregroundColor: NSColor.labelColor,
                ]
            )
        )
        // Centre the block vertically; long summaries fall back to filling the
        // available height and scrolling.
        let blockHeight = min(textHeight, available.height)
        textView.frame = NSRect(
            x: inset.width,
            y: (frame.height - blockHeight) / 2,
            width: available.width,
            height: blockHeight
        )
        textView.autoresizingMask = [.minXMargin, .maxXMargin, .minYMargin, .maxYMargin]

        let hint = NSTextField(labelWithString: "Press Escape to dismiss · copied to the clipboard")
        hint.font = .systemFont(ofSize: 12)
        hint.textColor = .tertiaryLabelColor
        hint.alignment = .center
        hint.frame = NSRect(
            x: 0, y: inset.height / 2.5, width: frame.width, height: 18)
        hint.autoresizingMask = [.width, .maxYMargin]

        background.addSubview(textView)
        background.addSubview(hint)

        super.init()
        window.delegate = self
    }

    /// When the window went up, so a click that was already in flight cannot
    /// dismiss it. The user reaches this window *by clicking* PopClip's button,
    /// and that mouse event can land here — large type flashing and vanishing
    /// before it is read.
    private var shownAt = Date.distantFuture
    private static let graceInterval: TimeInterval = 0.4

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        shownAt = Date()
    }

    /// False while the window is still too young to be dismissed by a click.
    var acceptsDismissal: Bool {
        Date().timeIntervalSince(shownAt) >= Self.graceInterval
    }

    @objc func dismiss() {
        window.close()
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.terminate(nil)
    }
}

// MARK: - Run

let app = NSApplication.shared
app.setActivationPolicy(.accessory)  // no Dock icon, no menu bar takeover

switch style {
case .panel:
    let controller = Controller(title: windowTitle, body: body)
    // Esc closes, like every other transient macOS panel.
    NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
        guard event.keyCode == 53 else { return event }
        controller.closePanel()
        return nil
    }
    controller.show()

case .fullscreen:
    let controller = FullScreenController(body: body)
    // Large type is a glance, not a document: Escape, Return, Space or a click
    // anywhere all dismiss it. ⌘C still copies a selection first.
    NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .leftMouseDown]) { event in
        guard controller.acceptsDismissal else { return nil }
        if event.type == .leftMouseDown {
            controller.dismiss()
            return nil
        }
        guard [53, 36, 49].contains(Int(event.keyCode)) else { return event }
        controller.dismiss()
        return nil
    }
    controller.show()
}

app.run()

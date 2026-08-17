//
//  NativeTextViewCoordinator.swift
//  MarkdownEngine
//
//  Created by Luca Chen on 18.02.26.
//

// Keeps the editor in sync while you type, updating formatting, selections,
// and other editing behavior in one place.
import AppKit
import SwiftUI

/// `NSTextViewDelegate` that bridges ``NativeTextViewWrapper`` and the
/// underlying `NSTextView`.
///
/// The coordinator is created automatically by SwiftUI; embedders never
/// construct one directly. Behaviors that don't fit in the main file live
/// in extensions (Autocorrect, CodeBlocks, Find, ImageEmbeds,
/// Notifications, Restyling, TextDelegate, WritingTools).
public final class NativeTextViewCoordinator: NSObject, NSTextViewDelegate {
    var documentId: String?
    var scrollYByDocumentID: [String: CGFloat] = [:]
    @Binding var text: String
    var fontName: String
    var fontSize: CGFloat
    var configuration: MarkdownEditorConfiguration = .default {
        didSet {
            subscribeToAppearanceNotification()
        }
    }
    private var registeredAppearanceObserverName: Notification.Name?
    weak var textView: NSTextView?
    var layoutBridge: LayoutBridge?
    var layoutDelegate: MarkdownLayoutManagerDelegate?
    var onCodeBlockSelectionChange: (([CodeBlockSelection]) -> Void)?
    var didInitialFormatting: Bool = false
    /// One-shot guard so `updateCodeBlockSelection` only forces a full-document layout once per document.
    var didEnsureLayoutForCurrentDocument: Bool = false
    var lastSyncedText: String
    var isProgrammaticEdit: Bool = false
    var isWritingToolsActive: Bool = false
    var wtStartDocumentId: String?
    weak var wtChildWindow: NSWindow?
    var wtInitialChildOrigin: CGPoint?
    var wtInitialSelectionRange: NSRange?
    enum WTMode { case unknown, proofread, rewrite }
    var wtDetectedMode: WTMode = .unknown
    var wtUndoObserverTokens: [NSObjectProtocol] = []
    var wtUndoneDuringSession: Bool = false
    var wtPostUndoSnapshot: String?
    var activeTokenIndices: Set<Int> = []
    var previousActiveTokenIndices: Set<Int> = []
    var previousBacktickCount: Int = 0

    var pendingEditedRange: NSRange? = nil
    var pendingPreEditActiveTokenIndices: Set<Int>? = nil
    var previousCaretLocation: Int? = nil

    var cachedCodeBlockTokens: [(index: Int, token: MarkdownToken)] = []
    var cachedParsedText: String?
    var cachedParsedDocument: ParsedDocument?
    // Skip spellcheck property setters when the state wouldn't change.
    var cachedSpellingDisabled: Bool?

    struct ParsedDocument {
        let tokens: [MarkdownToken]
        let codeTokens: [MarkdownToken]
        let latexTokens: [MarkdownToken]
        let blockLatexTokens: [MarkdownToken]
        let imageEmbedTokens: [MarkdownToken]
    }

    // Image-embed activation lives in
    // `NativeTextViewCoordinator+InlineSelection.swift`.

    init(text: Binding<String>,
         fontName: String,
         fontSize: CGFloat) {
        _text = text
        self.fontName = fontName
        self.fontSize = fontSize
        self.lastSyncedText = text.wrappedValue
        super.init()
        // Init + didSet share this helper so the observer tracks whichever service is current.
        subscribeToAppearanceNotification()
    }

    /// (Re)register the syntax-highlighter appearance observer; idempotent and unsubscribes on nil.
    private func subscribeToAppearanceNotification() {
        let target = configuration.services.syntaxHighlighter.appearanceDidChangeNotification
        if registeredAppearanceObserverName == target { return }
        if let current = registeredAppearanceObserverName {
            NotificationCenter.default.removeObserver(self, name: current, object: nil)
        }
        registeredAppearanceObserverName = nil
        guard let name = target else { return }
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppearanceChange(_:)),
            name: name,
            object: nil
        )
        registeredAppearanceObserverName = name
    }

    // Methods are split across the following extensions:
    //   - +TextDelegate    — NSTextViewDelegate hot path
    //   - +Restyling       — restyle pipeline + parsedDocument cache
    //   - +InlineSelection — image-embed activation
    //   - +CodeBlocks      — copy-button overlay
    //   - +Notifications   — appearance refresh
    //   - +Autocorrect     — spell/grammar/quote toggles
    //   - +WritingTools    — macOS 15+ Writing Tools session

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

extension NSTextView {
    func viewRect(forCharacterRange range: NSRange, using bridge: LayoutBridge?) -> CGRect? {
        guard range.location != NSNotFound,
              let bridge = bridge,
              let textContainer = textContainer else { return nil }
        var boundingRect = bridge.boundingRect(forCharacterRange: range, in: textContainer)
        let containerOrigin = textContainerOrigin
        boundingRect.origin.x += containerOrigin.x
        boundingRect.origin.y += containerOrigin.y
        if let scrollView = enclosingScrollView {
            let contentOffset = scrollView.contentView.bounds.origin
            boundingRect.origin.x -= contentOffset.x
            boundingRect.origin.y -= contentOffset.y
        }
        return boundingRect
    }
}

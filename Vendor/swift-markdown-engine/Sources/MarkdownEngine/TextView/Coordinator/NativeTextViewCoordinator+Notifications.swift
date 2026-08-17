//
//  NativeTextViewCoordinator+Notifications.swift
//  MarkdownEngine
//
//  Created by Luca Chen on 16.03.26.
//
//  Refreshes styling when the syntax highlighter signals an appearance
//  change.
//

import AppKit

extension NativeTextViewCoordinator {
    @objc func handleAppearanceChange(_ notification: Notification) {
        guard let tv = textView else { return }
        // Only react if the notification came from our own text view or from nil (system-wide)
        if let sender = notification.object as? NSTextView, sender !== tv {
            return
        }
        let fullRange = NSRange(location: 0, length: (tv.string as NSString).length)
        restyleTextView(tv, paragraphCandidates: [fullRange])
    }
}

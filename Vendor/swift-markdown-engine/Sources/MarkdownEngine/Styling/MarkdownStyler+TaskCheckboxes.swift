//
//  MarkdownStyler+TaskCheckboxes.swift
//  MarkdownEngine
//
//  Created by Luca Chen on 16.03.26.
//
//  GitHub-style `- [ ] / - [x]` task checkbox styling.
//

import AppKit
import Foundation

extension MarkdownStyler {

    // MARK: Task List Checkboxes

    static func styleTaskCheckboxes(_ ctx: StylingContext) -> [StyledRange] {
        var attrs: [StyledRange] = []
        let taskMatches = MarkdownStyler.taskListRegex.matches(in: ctx.text, options: [], range: ctx.fullRange)
        for match in taskMatches {
            let markerRange = match.range(at: 2)
            let spacerRange = match.range(at: 3)
            let checkboxRange = match.range(at: 4)
            if checkboxRange.location == NSNotFound { continue }
            if MarkdownDetection.isInsideCodeBlock(range: checkboxRange, codeTokens: ctx.codeTokens) { continue }
            let checkboxText = ctx.nsText.substring(with: checkboxRange)
            let isChecked = checkboxText.range(of: "[x]", options: [.caseInsensitive]) != nil
            if markerRange.location != NSNotFound {
                let syntaxStart = markerRange.location
                let syntaxEnd = checkboxRange.location + checkboxRange.length
                let syntaxRange = NSRange(location: syntaxStart, length: max(0, syntaxEnd - syntaxStart))
                var isActiveSyntax = NSLocationInRange(ctx.caretLocation, syntaxRange)
                if !isActiveSyntax && ctx.caretLocation == syntaxEnd {
                    let lastIndex = syntaxEnd - 1
                    if lastIndex >= syntaxStart && lastIndex < ctx.nsText.length {
                        let lastChar = ctx.nsText.substring(with: NSRange(location: lastIndex, length: 1))
                        if lastChar != "\n" { isActiveSyntax = true }
                    }
                }
                if isActiveSyntax { continue }
                let afterCheckboxIndex = checkboxRange.location + checkboxRange.length
                if afterCheckboxIndex < ctx.nsText.length {
                    let spaceRange = NSRange(location: afterCheckboxIndex, length: 1)
                    let spaceChar = ctx.nsText.substring(with: spaceRange)
                    if spaceChar == " " && !isChecked {
                        let extraSpacing = HeadingHelpers.checkboxExtraSpacing(
                            font: ctx.baseFont,
                            configuration: ctx.configuration.checkbox
                        )
                        attrs.append((spaceRange, [.kern: extraSpacing]))
                    }
                }
            }
            if markerRange.location != NSNotFound {
                attrs.append((markerRange, [.foregroundColor: NSColor.clear]))
            }
            if spacerRange.location != NSNotFound {
                attrs.append((spacerRange, [.foregroundColor: NSColor.clear]))
            }
            attrs.append((checkboxRange, [
                .taskCheckbox: isChecked,
                .foregroundColor: NSColor.clear
            ]))
        }
        return attrs
    }
}

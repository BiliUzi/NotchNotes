//
//  MarkdownTokenizer+Emphasis.swift
//  MarkdownEngine
//
//  Created by Luca Chen on 05.05.26.
//
//  Parser for `**`-delimited bold text on a single line.
//

import Foundation

extension MarkdownTokenizer {
    private static let boldRegex = try! NSRegularExpression(
        pattern: #"(?<!\*)\*\*(?=\S)(.+?)(?<=\S)\*\*(?!\*)"#,
        options: []
    )

    static func parseEmphasisTokens(in text: String) -> [MarkdownToken] {
        let fullRange = NSRange(location: 0, length: (text as NSString).length)
        return boldRegex.matches(in: text, options: [], range: fullRange).map { match in
            let range = match.range(at: 0)
            return MarkdownToken(
                kind: .bold,
                range: range,
                contentRange: match.range(at: 1),
                markerRanges: [
                    NSRange(location: range.location, length: 2),
                    NSRange(location: NSMaxRange(range) - 2, length: 2)
                ]
            )
        }
    }
}

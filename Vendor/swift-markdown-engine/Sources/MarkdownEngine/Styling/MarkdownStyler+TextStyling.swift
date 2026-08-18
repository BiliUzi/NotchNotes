//
//  MarkdownStyler+TextStyling.swift
//  MarkdownEngine
//
//  Created by Luca Chen on 16.03.26.
//
//  Heading and bold attribute generation.
//

import AppKit
import Foundation

extension MarkdownStyler {

    // MARK: Headings

    static func styleHeadings(_ ctx: StylingContext) -> [StyledRange] {
        var attrs: [StyledRange] = []
        let headingTokens = ctx.tokens.filter { $0.kind == .heading }
        for token in headingTokens {
            let level = token.markerRanges.first?.length ?? 1
            let multiplier = ctx.configuration.headings.fontMultiplier(for: level)
            let fontSize = ctx.baseFont.pointSize * multiplier
            let headingBase = NSFont(name: ctx.fontName, size: fontSize) ?? NSFont.systemFont(ofSize: fontSize)
            let headingFont = NSFontManager.shared.convert(headingBase, toHaveTrait: .boldFontMask)

            let paraRange = ctx.nsText.paragraphRange(for: token.range)
            let headingLineHeight = ceil(layoutBridgeDefaultLineHeight(for: headingFont, using: ctx.layoutBridge)) + 1
            let headingPara = NSMutableParagraphStyle()
            headingPara.minimumLineHeight = headingLineHeight
            headingPara.maximumLineHeight = headingLineHeight
            let beforeEm = ctx.configuration.headings.topSpacingEm(for: level)
            headingPara.paragraphSpacingBefore = headingFont.pointSize * beforeEm
            headingPara.paragraphSpacing = ctx.baseParagraphSpacing
            attrs.append((paraRange, [.paragraphStyle: headingPara]))

            for markerRange in token.markerRanges {
                attrs.append((markerRange, [
                    .font: headingFont,
                    .foregroundColor: ctx.configuration.theme.headingMarker
                ]))
            }
            attrs.append((token.contentRange, [.font: headingFont]))
        }
        return attrs
    }

    // MARK: Bold

    static func styleEmphasis(_ ctx: StylingContext) -> [StyledRange] {
        let boldFont = boldFont(in: ctx)
        return ctx.tokens.compactMap { token -> StyledRange? in
            guard token.kind == .bold,
                  !MarkdownDetection.isInsideCodeBlock(range: token.range, codeTokens: ctx.codeTokens) else {
                return nil
            }
            return (token.contentRange, [.font: boldFont])
        }
    }

    private static func boldFont(in ctx: StylingContext) -> NSFont {
        let desc = ctx.baseDescriptor.withSymbolicTraits(.bold)
        return NSFont(descriptor: desc, size: ctx.baseFont.pointSize)
            ?? NSFontManager.shared.convert(ctx.baseFont, toHaveTrait: .boldFontMask)
    }

    // MARK: Links

    static func styleLinks(_ ctx: StylingContext) -> [StyledRange] {
        var attrs: [StyledRange] = []

        for (index, token) in ctx.tokens.enumerated() where token.kind == .link {
            guard !MarkdownDetection.isInsideCodeBlock(range: token.range, codeTokens: ctx.codeTokens),
                  let url = URL(string: ctx.nsText.substring(with: token.contentRange)) else {
                continue
            }

            attrs.append((token.contentRange, [
                .link: url,
                .foregroundColor: NSColor.systemBlue,
                .underlineStyle: NSUnderlineStyle.single.rawValue
            ]))

            let markerColor = ctx.activeTokenIndices.contains(index)
                ? ctx.configuration.theme.mutedText
                : NSColor.clear
            for markerRange in token.markerRanges {
                attrs.append((markerRange, [.foregroundColor: markerColor]))
            }
        }

        return attrs
    }

}

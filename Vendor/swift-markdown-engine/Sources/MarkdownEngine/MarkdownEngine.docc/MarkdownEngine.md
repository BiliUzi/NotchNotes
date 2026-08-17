# ``MarkdownEngine``

A TextKit 2-backed Markdown editor view for macOS, bridged to SwiftUI.

## Overview

MarkdownEngine provides a native AppKit Markdown editor with live styling,
fenced code blocks with syntax highlighting, LaTeX rendering, embedded images,
and GitHub-style task checkboxes.

The engine itself has **zero external dependencies**. Everything app-specific
is injected through small service protocols, so embedders stay in control of
where embedded images live, how code is highlighted, and how LaTeX is rendered.

### Quick Start

```swift
import SwiftUI
import MarkdownEngine

struct EditorScreen: View {
    @State private var text: String = "# Hello, **world**"

    var body: some View {
        NativeTextViewWrapper(
            text: $text,
            configuration: .default,
            fontName: "SF Pro",
            documentId: "doc-1"
        )
    }
}
```

The default ``MarkdownEditorConfiguration`` ships with no-op service
implementations, so the editor renders plain Markdown out of the box. Add
real services as you need them.

### Customizing Appearance

```swift
var theme = MarkdownEditorTheme.default
theme.bodyText = .labelColor
theme.headingMarker = .secondaryLabelColor

var configuration = MarkdownEditorConfiguration.default
configuration.theme = theme
```

### Wiring Up Services

```swift
let services = MarkdownEditorServices(
    images:    MyImageProvider(),
    syntaxHighlighter: MySyntaxHighlighter(),
    latex:     MyLatexRenderer()
)

var configuration = MarkdownEditorConfiguration.default
configuration.services = services
```

## Topics

### Editor View

- ``NativeTextViewWrapper``

### Configuration

- ``MarkdownEditorConfiguration``
- ``MarkdownEditorTheme``

### Service Protocols

- ``EmbeddedImageProvider``
- ``SyntaxHighlighter``
- ``LatexRenderer``

### Services Container

- ``MarkdownEditorServices``

### Default No-Op Implementations

- ``NoOpEmbeddedImageProvider``
- ``PlainTextSyntaxHighlighter``
- ``NoOpLatexRenderer``

### Code Blocks

- ``CodeBlockSelection``

### Pasteboard Helpers

- ``PasteboardImageReader``

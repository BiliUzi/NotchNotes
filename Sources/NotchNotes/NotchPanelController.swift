import AppKit
import SwiftUI

enum AppKeyboardShortcut: Equatable {
    case newNote
    case hideNotes
    case quit
    case undo
    case redo
    case cut
    case copy
    case paste
    case selectAll
    case showFind
    case findNext
    case findPrevious

    init?(charactersIgnoringModifiers: String?, modifierFlags: NSEvent.ModifierFlags) {
        let modifiers = modifierFlags.intersection([.command, .shift, .option, .control])
        guard !modifiers.contains(.option),
              !modifiers.contains(.control),
              let key = charactersIgnoringModifiers?.lowercased() else {
            return nil
        }

        switch (key, modifiers) {
        case ("n", [.command]): self = .newNote
        case ("w", [.command]): self = .hideNotes
        case ("q", [.command]): self = .quit
        case ("z", [.command]): self = .undo
        case ("z", [.command, .shift]): self = .redo
        case ("x", [.command]): self = .cut
        case ("c", [.command]): self = .copy
        case ("v", [.command]): self = .paste
        case ("a", [.command]): self = .selectAll
        case ("f", [.command]): self = .showFind
        case ("g", [.command]): self = .findNext
        case ("g", [.command, .shift]): self = .findPrevious
        default: return nil
        }
    }
}

@MainActor
final class NotchPanel: NSPanel {
    var onMouseEvent: ((NSEvent) -> Void)?
    var onEscape: (() -> Void)?
    var onKeyboardShortcut: ((AppKeyboardShortcut) -> Bool)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown {
            if event.keyCode == 53 {
                onEscape?()
                return
            }

            if let shortcut = AppKeyboardShortcut(
                charactersIgnoringModifiers: event.charactersIgnoringModifiers,
                modifierFlags: event.modifierFlags
            ), onKeyboardShortcut?(shortcut) == true {
                return
            }
        }

        if event.type == .leftMouseDown || event.type == .leftMouseDragged || event.type == .leftMouseUp {
            onMouseEvent?(event)
        }

        super.sendEvent(event)
    }
}

@MainActor
class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }
}

@MainActor
class TransparentHitHostingView<Content: View>: FirstMouseHostingView<Content> {
    override func hitTest(_ point: NSPoint) -> NSView? {
        guard bounds.contains(point) else { return nil }
        // SwiftUI may return nil when every rendered pixel is transparent.
        // Keep the panel's full compact frame interactive without drawing a background.
        return super.hitTest(point) ?? self
    }
}

@MainActor
final class CompactFileDropHostingView<Content: View>: TransparentHitHostingView<Content> {
    var onFileDragTargeted: ((Bool) -> Void)?
    var onFilesDropped: (([URL]) -> Bool)?

    private var isFileDragTargeted = false

    required init(rootView: Content) {
        super.init(rootView: rootView)
        registerForDraggedTypes([.fileURL])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard FileDropPasteboardReader.containsFileURLs(sender.draggingPasteboard) else { return [] }
        setFileDragTargeted(true)
        return .copy
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        FileDropPasteboardReader.containsFileURLs(sender.draggingPasteboard) ? .copy : []
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        setFileDragTargeted(false)
    }

    override func draggingEnded(_ sender: NSDraggingInfo) {
        setFileDragTargeted(false)
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        FileDropPasteboardReader.containsFileURLs(sender.draggingPasteboard)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        defer { setFileDragTargeted(false) }
        let urls = FileDropPasteboardReader.fileURLs(from: sender.draggingPasteboard)
        guard !urls.isEmpty else { return false }
        return onFilesDropped?(urls) ?? false
    }

    private func setFileDragTargeted(_ isTargeted: Bool) {
        guard isFileDragTargeted != isTargeted else { return }
        isFileDragTargeted = isTargeted
        onFileDragTargeted?(isTargeted)
    }
}

@MainActor
final class NotchPanelController: NSObject {
    private let store = NoteStore()
    private let imageStore = LocalImageStore()
    private let fileShelfStore = FileShelfStore()
    private let workspaceState = NotebookWorkspaceState()
    private let drawerState = DrawerState()
    private let editorInteractionState = EditorInteractionState()
    private let hotPanel: NotchPanel
    private let drawerPanel: NotchPanel
    private var hostingView: NSHostingView<NotebookView>?
    private var hotHostingView: CompactFileDropHostingView<CompactNotchView>?
    private var mousePollingTimer: Timer?
    private var localMouseDownMonitor: Any?
    private var globalMouseDownMonitor: Any?
    private var globalMouseDragMonitor: Any?
    private var globalMouseUpMonitor: Any?
    private var isExpanded = false
    private var isRevealedForFileDrag = false
    private var isLeftMouseDragging = false
    private var dragPasteboardChangeCountAtMouseDown: Int?

    override init() {
        hotPanel = NotchPanel(
            contentRect: .zero,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        drawerPanel = NotchPanel(
            contentRect: .zero,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        super.init()
        configurePanel(hotPanel)
        configurePanel(drawerPanel)
        hotPanel.ignoresMouseEvents = true
        rebuildContent()
        startMousePolling()
        observeScreenChanges()
        observePanelMouseEvents()
        observeMouseMonitors()
    }

    func showDocked() {
        let layout = currentLayout()
        rebuildContent(layout: layout)
        isExpanded = false
        isRevealedForFileDrag = false
        drawerState.isExpanded = false
        drawerState.revealProgress = 0
        hotPanel.setFrame(hotFrame(for: layout), display: true)
        hotPanel.ignoresMouseEvents = true
        hotPanel.orderFrontRegardless()
        drawerPanel.setFrame(drawerFrame(for: layout), display: true)
        drawerPanel.orderOut(nil)
    }

    func expand(animated: Bool, activate: Bool = true) {
        if isExpanded {
            finishFileDragRevealIfNeeded()
            if activate {
                activateEditor()
            }
            return
        }
        let layout = currentLayout()
        isExpanded = true
        isRevealedForFileDrag = false
        rebuildContent(layout: layout)
        drawerPanel.setFrame(drawerFrame(for: layout), display: true)
        if activate {
            NSApp.activate(ignoringOtherApps: true)
            drawerPanel.makeKeyAndOrderFront(nil)
        } else {
            drawerPanel.orderFrontRegardless()
        }
        hotPanel.orderOut(nil)
        setDrawerExpanded(true, animated: animated)
        guard activate else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) { [weak self] in
            guard let self else { return }
            guard self.isExpanded else { return }
            self.activateEditor()
        }
    }

    func collapse(animated: Bool) {
        guard isExpanded else { return }
        if let range = editorInteractionState.currentSelectionRange() {
            store.updateSelection(for: store.activeTabID, range: range)
        }
        store.flush(waitForDisk: false)
        isExpanded = false
        isRevealedForFileDrag = false
        workspaceState.isShelfDropTargeted = false
        setDrawerExpanded(false, animated: animated)
        let delay: TimeInterval = animated ? 0.18 : 0
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self else { return }
            guard !self.isExpanded else { return }
            let layout = self.currentLayout()
            self.drawerPanel.orderOut(nil)
            self.hotPanel.setFrame(self.hotFrame(for: layout), display: true)
            self.hotPanel.ignoresMouseEvents = true
            self.hotPanel.orderFrontRegardless()
        }
    }

    func createNote() {
        if let range = editorInteractionState.currentSelectionRange() {
            store.updateSelection(for: store.activeTabID, range: range)
        }
        store.addTab()
        expand(animated: true, activate: true)
    }

    private func configurePanel(_ panel: NotchPanel) {
        panel.appearance = NSAppearance(named: .darkAqua)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isMovable = false
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .none
        panel.acceptsMouseMovedEvents = true
    }

    private func rebuildContent(layout: NotchLayout? = nil) {
        let layout = layout ?? currentLayout()
        let hotView = CompactNotchView(layout: layout)
        let view = NotebookView(
            store: store,
            imageStore: imageStore,
            fileShelfStore: fileShelfStore,
            workspaceState: workspaceState,
            drawerState: drawerState,
            editorInteractionState: editorInteractionState,
            layout: layout
        )

        if let hotHostingView {
            hotHostingView.rootView = hotView
            configureCompactFileDropCallbacks(hotHostingView)
        } else {
            let host = CompactFileDropHostingView(rootView: hotView)
            configureCompactFileDropCallbacks(host)
            host.translatesAutoresizingMaskIntoConstraints = true
            host.autoresizingMask = [.width, .height]
            host.wantsLayer = true
            host.layer?.masksToBounds = true
            hotPanel.contentView = host
            hotHostingView = host
        }

        if let hostingView {
            hostingView.rootView = view
            return
        }

        let host = FirstMouseHostingView(rootView: view)
        host.translatesAutoresizingMaskIntoConstraints = false
        host.wantsLayer = true
        host.layer?.masksToBounds = true
        drawerPanel.contentView = host
        hostingView = host
    }

    private func configureCompactFileDropCallbacks(
        _ host: CompactFileDropHostingView<CompactNotchView>
    ) {
        host.onFileDragTargeted = { [weak self] isTargeted in
            self?.handleFileDragTargeted(isTargeted)
        }
        host.onFilesDropped = { [weak self] urls in
            self?.receiveDroppedFiles(urls) ?? false
        }
    }

    private func setDrawerExpanded(_ expanded: Bool, animated: Bool) {
        guard animated else {
            drawerState.isExpanded = expanded
            drawerState.revealProgress = expanded ? 1 : 0
            return
        }

        let animation: Animation = expanded
            ? .spring(response: 0.28, dampingFraction: 0.86)
            : .easeOut(duration: 0.16)

        withAnimation(animation) {
            drawerState.isExpanded = expanded
            drawerState.revealProgress = expanded ? 1 : 0
        }
    }

    private func startMousePolling() {
        let timer = Timer(
            timeInterval: 1.0 / 30.0,
            target: self,
            selector: #selector(mousePollingTick),
            userInfo: nil,
            repeats: true
        )
        RunLoop.main.add(timer, forMode: .common)
        mousePollingTimer = timer
    }

    private func observeScreenChanges() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    private func observePanelMouseEvents() {
        drawerPanel.onMouseEvent = { [weak self] event in
            guard let self else { return }
            if event.type == .leftMouseDown {
                NSApp.activate(ignoringOtherApps: true)
                self.drawerPanel.makeKeyAndOrderFront(nil)
            } else if event.type == .leftMouseUp {
                self.workspaceState.isDraggingShelfItem = false
                self.resetFileDropState()
            }
            self.editorInteractionState.handleMouseEvent(event, searchingIn: self.hostingView)
        }

        hotPanel.onEscape = { [weak self] in self?.collapse(animated: true) }
        drawerPanel.onEscape = { [weak self] in self?.collapse(animated: true) }
        hotPanel.onKeyboardShortcut = { [weak self] shortcut in
            self?.handleKeyboardShortcut(shortcut) ?? false
        }
        drawerPanel.onKeyboardShortcut = { [weak self] shortcut in
            self?.handleKeyboardShortcut(shortcut) ?? false
        }
    }

    private func handleKeyboardShortcut(_ shortcut: AppKeyboardShortcut) -> Bool {
        switch shortcut {
        case .newNote:
            createNote()
            return true
        case .hideNotes:
            collapse(animated: true)
            return true
        case .quit:
            NSApp.terminate(nil)
            return true
        case .undo:
            return sendResponderAction(Selector(("undo:")))
        case .redo:
            return sendResponderAction(Selector(("redo:")))
        case .cut:
            return sendResponderAction(#selector(NSText.cut(_:)))
        case .copy:
            return sendResponderAction(#selector(NSText.copy(_:)))
        case .paste:
            return sendResponderAction(#selector(NSText.paste(_:)))
        case .selectAll:
            return sendResponderAction(#selector(NSText.selectAll(_:)))
        case .showFind:
            return sendFindAction(.showFindInterface)
        case .findNext:
            return sendFindAction(.nextMatch)
        case .findPrevious:
            return sendFindAction(.previousMatch)
        }
    }

    private func sendResponderAction(_ action: Selector) -> Bool {
        NSApp.sendAction(action, to: nil, from: nil)
    }

    private func sendFindAction(_ action: NSTextFinder.Action) -> Bool {
        let sender = NSButton()
        sender.tag = action.rawValue
        return NSApp.sendAction(
            #selector(NSTextView.performFindPanelAction(_:)),
            to: nil,
            from: sender
        )
    }

    private func observeMouseMonitors() {
        localMouseDownMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown]) { [weak self] event in
            let location = NSEvent.mouseLocation
            let dragPasteboardChangeCount = NSPasteboard(name: .drag).changeCount
            Task { @MainActor in
                self?.handleObservedMouseDown(
                    at: location,
                    dragPasteboardChangeCount: dragPasteboardChangeCount
                )
            }
            return event
        }

        globalMouseDownMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown]) { [weak self] _ in
            let location = NSEvent.mouseLocation
            let dragPasteboardChangeCount = NSPasteboard(name: .drag).changeCount
            Task { @MainActor in
                self?.handleObservedMouseDown(
                    at: location,
                    dragPasteboardChangeCount: dragPasteboardChangeCount
                )
            }
        }

        globalMouseDragMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDragged]) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.isLeftMouseDragging = true
                self.handleMouseLocation(NSEvent.mouseLocation)
            }
        }

        globalMouseUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseUp]) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.isLeftMouseDragging = false
                self.dragPasteboardChangeCountAtMouseDown = nil
                self.workspaceState.isDraggingShelfItem = false
                self.resetFileDropState()
                self.finishFileDragRevealIfNeeded()
                let location = NSEvent.mouseLocation
                if self.isExpanded, !self.isPointInExpandedStayRegion(location) {
                    self.collapse(animated: true)
                } else {
                    self.handleMouseLocation(location)
                }
            }
        }
    }

    private func handleObservedMouseDown(
        at location: NSPoint,
        dragPasteboardChangeCount: Int
    ) {
        isLeftMouseDragging = false
        dragPasteboardChangeCountAtMouseDown = dragPasteboardChangeCount

        guard !isExpanded,
              clickActivationFrame(at: location).contains(location) else {
            return
        }
        expand(animated: true, activate: true)
    }

    @objc private func screenParametersChanged(_ notification: Notification) {
        let layout = currentLayout()
        rebuildContent(layout: layout)
        hotPanel.setFrame(hotFrame(for: layout), display: true)
        drawerPanel.setFrame(drawerFrame(for: layout), display: true)
    }

    @objc private func mousePollingTick(_ timer: Timer) {
        handleMouseLocation(NSEvent.mouseLocation)
    }

    private func handleMouseLocation(_ point: NSPoint) {
        let dragPasteboard = NSPasteboard(name: .drag)
        if !isExpanded,
           NSEvent.pressedMouseButtons & 1 == 1,
           dropActivationFrame().contains(point),
           CompactFileDropActivationPolicy.shouldActivate(
               isLeftMouseDragging: isLeftMouseDragging,
               pasteboardChangeCountAtMouseDown: dragPasteboardChangeCountAtMouseDown,
               currentPasteboardChangeCount: dragPasteboard.changeCount,
               containsFileURLs: FileDropPasteboardReader.containsFileURLs(dragPasteboard)
           ) {
            hotPanel.ignoresMouseEvents = false
            handleFileDragTargeted(true)
            return
        }

        if isExpanded { return }

        hotPanel.ignoresMouseEvents = true
    }

    private func dropActivationFrame() -> NSRect {
        let layout = currentLayout()
        let frame = hotPanel.frame
        guard frame.width > 0, frame.height > 0 else {
            return hotFrame(for: layout)
        }

        return frame
    }

    private func clickActivationFrame(at point: NSPoint) -> NSRect {
        guard let screen = screenContaining(point) ?? targetScreen(), screen.frame.contains(point) else {
            return .zero
        }
        return NotchGeometry.centerTopActivationFrame(
            screenFrame: screen.frame,
            menuBarHeight: screen.menuBarHeight
        ) ?? .zero
    }

    private func isPointInExpandedStayRegion(_ point: NSPoint) -> Bool {
        let margin: CGFloat = 10
        return drawerPanel.frame.insetBy(dx: -margin, dy: -margin).contains(point)
            || clickActivationFrame(at: point).contains(point)
    }

    private func screenContaining(_ point: NSPoint) -> NSScreen? {
        NSScreen.screens.first { $0.frame.contains(point) }
    }

    private func receiveDroppedFiles(_ urls: [URL]) -> Bool {
        guard fileShelfStore.acceptDrop(urls) else {
            resetFileDropState()
            return false
        }

        resetFileDropState()

        // Do not replace the NSWindow that owns the active dragging destination
        // until AppKit has finished the drop callback and closed its tracking loop.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if self.isExpanded {
                self.finishFileDragRevealIfNeeded()
            } else {
                self.expand(animated: true, activate: false)
            }
        }
        return true
    }

    private func handleFileDragTargeted(_ isTargeted: Bool) {
        if !isTargeted {
            hotPanel.ignoresMouseEvents = true
        }

        withAnimation(.spring(response: 0.30, dampingFraction: 0.84)) {
            workspaceState.isShelfDropTargeted = isTargeted
        }

        if isTargeted {
            revealDrawerForFileDrag()
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.finishFileDragRevealIfNeeded()
            }
        }
    }

    private func resetFileDropState() {
        workspaceState.isShelfDropTargeted = false
    }

    private func revealDrawerForFileDrag() {
        guard !isExpanded else { return }

        let layout = currentLayout()
        isExpanded = true
        isRevealedForFileDrag = true
        drawerPanel.setFrame(drawerFrame(for: layout), display: true)
        drawerPanel.orderFrontRegardless()
        hotPanel.orderFrontRegardless()
        setDrawerExpanded(true, animated: true)
    }

    private func finishFileDragRevealIfNeeded() {
        guard isRevealedForFileDrag else { return }
        isRevealedForFileDrag = false
        hotPanel.ignoresMouseEvents = true
        hotPanel.orderOut(nil)
        drawerPanel.orderFrontRegardless()
    }

    func flush() {
        store.flush(waitForDisk: true)
    }

    private func activateEditor() {
        NSApp.activate(ignoringOtherApps: true)
        drawerPanel.makeKeyAndOrderFront(nil)
        editorInteractionState.restoreSelection(
            store.selectionRange(for: store.activeTabID),
            searchingIn: hostingView
        )
        editorInteractionState.requestLayoutRefresh(searchingIn: hostingView)
        editorInteractionState.requestFocus(searchingIn: hostingView)
    }

    private func currentLayout() -> NotchLayout {
        NotchGeometry.layout(for: targetScreen())
    }

    private func targetScreen() -> NSScreen? {
        NotchGeometry.targetScreen()
    }

    private func hotFrame(for layout: NotchLayout) -> NSRect {
        let screen = targetScreen()
        let screenFrame = screen?.frame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        // The physical notch itself is not a reliable pointer target: the cursor
        // normally stops just below its lower edge. Keep the compact visual size
        // unchanged, but extend the transparent native dragging destination far
        // enough below the notch for Finder to actually enter it.
        let dropTargetSize = NSSize(
            width: layout.compactSize.width,
            height: layout.compactSize.height + 28
        )
        return frame(for: dropTargetSize, in: screenFrame)
    }

    private func drawerFrame(for layout: NotchLayout) -> NSRect {
        let screen = targetScreen()
        let screenFrame = screen?.frame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        return frame(for: layout.expandedSize, in: screenFrame)
    }

    private func frame(for size: NSSize, in screenFrame: NSRect) -> NSRect {
        let x = screenFrame.midX - size.width / 2
        let y = screenFrame.maxY - size.height

        return NSRect(x: x, y: y, width: size.width, height: size.height)
    }
}

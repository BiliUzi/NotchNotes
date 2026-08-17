import AppKit
import Foundation
import MarkdownEngine

final class LocalImageStore: EmbeddedImageProvider, @unchecked Sendable {
    private let directoryURL: URL
    private let lock = NSLock()
    private var version = 0
    private let imageExtension = "png"

    init() {
        let supportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        directoryURL = supportURL.appendingPathComponent("NotchNotes/Images", isDirectory: true)
        try? FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    }

    func saveImage(from pasteboard: NSPasteboard) -> String? {
        if let fileURL = PasteboardImageReader.imageFileURL(from: pasteboard),
           let data = try? Data(contentsOf: fileURL),
           NSImage(data: data) != nil {
            return save(
                data: pngData(fromImageData: data) ?? data,
                originalName: fileURL.deletingPathExtension().lastPathComponent
            )
        }

        guard let pngData = PasteboardImageReader.imageData(from: pasteboard) else {
            return nil
        }

        return save(
            data: pngData,
            originalName: "pasted-image"
        )
    }

    func image(for reference: EmbeddedImageRequest) -> NSImage? {
        for candidateName in candidateNames(for: reference) {
            let url = imageURL(for: candidateName)
            if let image = NSImage(contentsOf: url) {
                return image
            }
        }

        return nil
    }

    func fingerprint() -> AnyHashable {
        lock.lock()
        defer { lock.unlock() }
        return version
    }

    private func save(data: Data, originalName: String) -> String? {
        let displayName = sanitizedDisplayName(originalName)
        let id = UUID()
        let url = imageURL(for: id.uuidString)

        do {
            try data.write(to: url, options: .atomic)
            lock.lock()
            version += 1
            lock.unlock()
            return "![[\(displayName)|\(id.uuidString)]]"
        } catch {
            return nil
        }
    }

    private func candidateNames(for reference: EmbeddedImageRequest) -> [String] {
        [reference.id, reference.name].compactMap { $0 }
    }

    private func imageURL(for idOrName: String) -> URL {
        if idOrName.lowercased().hasSuffix(".\(imageExtension)") {
            return directoryURL.appendingPathComponent(idOrName)
        }

        return directoryURL.appendingPathComponent("\(idOrName).\(imageExtension)")
    }

    private func sanitizedDisplayName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallback = trimmed.isEmpty ? "pasted-image" : trimmed
        return fallback
            .replacingOccurrences(of: "|", with: "-")
            .replacingOccurrences(of: "[", with: "")
            .replacingOccurrences(of: "]", with: "")
            .replacingOccurrences(of: "\n", with: " ")
    }

    private func pngData(fromImageData data: Data) -> Data? {
        guard let image = NSImage(data: data),
              let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            return nil
        }

        return bitmap.representation(using: .png, properties: [:])
    }
}

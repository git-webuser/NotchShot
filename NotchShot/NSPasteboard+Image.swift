import AppKit
import ImageIO

extension NSPasteboard {

    /// Копирует изображение по URL в буфер обмена.
    /// Если CGImage не удаётся декодировать — копирует только URL.
    func writeImage(at url: URL) {
        Task.detached(priority: .userInitiated) {
            let image: NSImage? = autoreleasepool {
                guard
                    let src = CGImageSourceCreateWithURL(url as CFURL, nil),
                    let cgImage = CGImageSourceCreateImageAtIndex(src, 0, nil)
                else { return nil }
                return NSImage(cgImage: cgImage, size: .zero)
            }
            await MainActor.run {
                self.clearContents()
                if let image {
                    self.writeObjects([image, url as NSURL])
                } else {
                    self.writeObjects([url as NSURL])
                }
            }
        }
    }
}

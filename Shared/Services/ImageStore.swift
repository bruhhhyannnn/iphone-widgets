import UIKit

/// Stores launcher icons and drawer photos in the shared container so widgets can read them.
enum ImageStore {
    static let iconsFolder = "Icons"
    static let backgroundsFolder = "Backgrounds"

    static func folder(_ name: String) -> URL {
        let url = AppGroup.containerURL.appendingPathComponent(name, isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func url(for file: String, in folderName: String) -> URL {
        folder(folderName).appendingPathComponent(file)
    }

    /// Loads an image from the shared container, downscaled so widgets stay under their memory limit.
    static func image(_ file: String?, in folderName: String, maxPixel: CGFloat = 180) -> UIImage? {
        guard let file else { return nil }
        let path = url(for: file, in: folderName).path
        guard let image = UIImage(contentsOfFile: path) else { return nil }
        return downscaled(image, maxPixel: maxPixel)
    }

    @discardableResult
    static func save(_ image: UIImage, in folderName: String, maxPixel: CGFloat, name: String = UUID().uuidString, jpeg: Bool = false) -> String? {
        let scaled = downscaled(image, maxPixel: maxPixel)
        let file = name + (jpeg ? ".jpg" : ".png")
        let data = jpeg ? scaled.jpegData(compressionQuality: 0.85) : scaled.pngData()
        guard let data else { return nil }
        do {
            try data.write(to: url(for: file, in: folderName), options: .atomic)
            return file
        } catch {
            return nil
        }
    }

    static func delete(_ file: String?, in folderName: String) {
        guard let file else { return }
        try? FileManager.default.removeItem(at: url(for: file, in: folderName))
    }

    static func downscaled(_ image: UIImage, maxPixel: CGFloat) -> UIImage {
        let pixelWidth = image.size.width * image.scale
        let pixelHeight = image.size.height * image.scale
        let largest = max(pixelWidth, pixelHeight)
        guard largest > maxPixel, largest > 0 else { return image }
        let ratio = maxPixel / largest
        let size = CGSize(width: (pixelWidth * ratio).rounded(), height: (pixelHeight * ratio).rounded())
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

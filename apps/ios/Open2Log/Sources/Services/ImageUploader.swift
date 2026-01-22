import Foundation
import UIKit

/// Handles uploading images to R2 via presigned URLs
class ImageUploader {
    private let apiClient: APIClient
    private let session: URLSession

    init(apiClient: APIClient = APIClient()) {
        self.apiClient = apiClient
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        self.session = URLSession(configuration: config)
    }

    enum UploadType: String {
        case barcode
        case price
        case product
    }

    /// Upload image data and return the public URL
    func uploadImage(_ data: Data, type: UploadType) async throws -> String {
        return try await upload(imageData: data, type: type)
    }

    /// Upload image data and return the public URL
    func upload(imageData: Data, type: UploadType) async throws -> String {
        // Determine content type based on data
        let contentType = detectContentType(imageData)
        let filename = "\(UUID().uuidString).\(fileExtension(for: contentType))"

        // Get presigned upload URL from our worker
        let urlResponse = try await apiClient.getUploadUrl(
            filename: filename,
            contentType: contentType,
            uploadType: type.rawValue
        )

        // Upload directly to R2
        var request = URLRequest(url: URL(string: urlResponse.uploadUrl)!)
        request.httpMethod = "PUT"
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.httpBody = imageData

        let (_, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw ImageUploadError.uploadFailed
        }

        return urlResponse.publicUrl
    }

    /// Compress and encode image as AVIF
    func prepareImage(_ image: UIImage, maxDimension: CGFloat = 1024) -> Data? {
        // Resize if needed
        let resized = resize(image, maxDimension: maxDimension)

        // Try AVIF first, then HEIC, then JPEG
        if let avif = encodeAsAVIF(resized) {
            return avif
        }

        if let heic = resized.heicData() {
            return heic
        }

        return resized.jpegData(compressionQuality: 0.8)
    }

    private func resize(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let ratio = min(maxDimension / size.width, maxDimension / size.height)

        if ratio >= 1 { return image }

        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        let renderer = UIGraphicsImageRenderer(size: newSize)

        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    private func encodeAsAVIF(_ image: UIImage) -> Data? {
        guard let cgImage = image.cgImage else { return nil }

        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data,
            "public.avif" as CFString,
            1,
            nil
        ) else { return nil }

        let options: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: 0.75
        ]

        CGImageDestinationAddImage(destination, cgImage, options as CFDictionary)

        guard CGImageDestinationFinalize(destination) else { return nil }

        return data as Data
    }

    private func detectContentType(_ data: Data) -> String {
        guard data.count >= 12 else { return "application/octet-stream" }

        let bytes = [UInt8](data.prefix(12))

        // AVIF: starts with ftyp box containing "avif" or "avis"
        if bytes[4...7] == [0x66, 0x74, 0x79, 0x70] { // "ftyp"
            let brand = String(bytes: bytes[8...11], encoding: .ascii) ?? ""
            if brand == "avif" || brand == "avis" {
                return "image/avif"
            }
            if brand == "heic" || brand == "heix" {
                return "image/heic"
            }
        }

        // JPEG
        if bytes[0...1] == [0xFF, 0xD8] {
            return "image/jpeg"
        }

        // PNG
        if bytes[0...7] == [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A] {
            return "image/png"
        }

        // WebP
        if bytes[0...3] == [0x52, 0x49, 0x46, 0x46] && bytes[8...11] == [0x57, 0x45, 0x42, 0x50] {
            return "image/webp"
        }

        return "application/octet-stream"
    }

    private func fileExtension(for contentType: String) -> String {
        switch contentType {
        case "image/avif": return "avif"
        case "image/heic": return "heic"
        case "image/jpeg": return "jpg"
        case "image/png": return "png"
        case "image/webp": return "webp"
        default: return "bin"
        }
    }
}

enum ImageUploadError: Error, LocalizedError {
    case uploadFailed
    case encodingFailed

    var errorDescription: String? {
        switch self {
        case .uploadFailed: return "Failed to upload image"
        case .encodingFailed: return "Failed to encode image"
        }
    }
}

extension UIImage {
    func heicData() -> Data? {
        guard let cgImage = self.cgImage else { return nil }

        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data,
            "public.heic" as CFString,
            1,
            nil
        ) else { return nil }

        CGImageDestinationAddImage(destination, cgImage, nil)
        CGImageDestinationFinalize(destination)

        return data as Data
    }
}

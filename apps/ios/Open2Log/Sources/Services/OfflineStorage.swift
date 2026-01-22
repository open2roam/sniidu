import Foundation
import SwiftData
import CoreLocation

/// Manages all offline data storage using SwiftData
@MainActor
class OfflineStorage: ObservableObject {
    let container: ModelContainer
    let context: ModelContext

    @Published var pendingUploadsCount: Int = 0

    init() throws {
        let schema = Schema([
            PendingUpload.self,
            CachedShop.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: false)
        container = try ModelContainer(for: schema, configurations: config)
        context = container.mainContext
    }

    // MARK: - Pending Uploads

    func savePendingUpload(_ upload: PendingUpload) {
        context.insert(upload)
        try? context.save()
        updatePendingCount()
    }

    func getPendingUploads() -> [PendingUpload] {
        let descriptor = FetchDescriptor<PendingUpload>(
            predicate: #Predicate { !$0.dataUploaded },
            sortBy: [SortDescriptor(\.scannedAt, order: .forward)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    func getRetryablePendingUploads() -> [PendingUpload] {
        let descriptor = FetchDescriptor<PendingUpload>(
            predicate: #Predicate { !$0.dataUploaded && $0.uploadAttempts < 10 },
            sortBy: [SortDescriptor(\.scannedAt, order: .forward)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    func markUploadComplete(_ upload: PendingUpload) {
        upload.dataUploaded = true
        try? context.save()
        updatePendingCount()
    }

    func markUploadFailed(_ upload: PendingUpload, error: String) {
        upload.uploadAttempts += 1
        upload.lastAttemptAt = Date()
        upload.error = error
        try? context.save()
    }

    func deletePendingUpload(_ upload: PendingUpload) {
        context.delete(upload)
        try? context.save()
        updatePendingCount()
    }

    func clearCompletedUploads() {
        let descriptor = FetchDescriptor<PendingUpload>(
            predicate: #Predicate { $0.dataUploaded }
        )
        if let completed = try? context.fetch(descriptor) {
            for upload in completed {
                // Clean up local image files
                deleteLocalFile(upload.barcodeImagePath)
                deleteLocalFile(upload.priceImagePath)
                deleteLocalFile(upload.productImagePath)
                context.delete(upload)
            }
            try? context.save()
        }
    }

    private func updatePendingCount() {
        let descriptor = FetchDescriptor<PendingUpload>(
            predicate: #Predicate { !$0.dataUploaded }
        )
        pendingUploadsCount = (try? context.fetchCount(descriptor)) ?? 0
    }

    private func deleteLocalFile(_ path: String?) {
        guard let path = path else { return }
        try? FileManager.default.removeItem(atPath: path)
    }

    // MARK: - Cached Shops

    func cacheShops(_ shops: [Shop]) {
        // Remove expired cached shops first
        clearExpiredShops()

        for shop in shops {
            // Check if already cached
            let existingDescriptor = FetchDescriptor<CachedShop>(
                predicate: #Predicate { $0.id == shop.id }
            )

            if let existing = try? context.fetch(existingDescriptor).first {
                // Update existing
                existing.cachedAt = Date()
                existing.expiresAt = Date().addingTimeInterval(7 * 24 * 3600)
            } else {
                // Insert new
                let cached = CachedShop(from: shop)
                context.insert(cached)
            }
        }
        try? context.save()
    }

    func getCachedShops() -> [Shop] {
        let descriptor = FetchDescriptor<CachedShop>(
            predicate: #Predicate { $0.expiresAt > Date() }
        )
        let cached = (try? context.fetch(descriptor)) ?? []
        return cached.map { $0.toShop() }
    }

    func getCachedShopsNear(latitude: Double, longitude: Double, radiusKm: Double) -> [Shop] {
        let allShops = getCachedShops()
        let center = CLLocation(latitude: latitude, longitude: longitude)
        let radiusMeters = radiusKm * 1000

        return allShops.filter { shop in
            shop.distance(from: center) <= radiusMeters
        }
    }

    func getCachedShop(byGersId gersId: String) -> Shop? {
        let descriptor = FetchDescriptor<CachedShop>(
            predicate: #Predicate { $0.gersId == gersId }
        )
        return (try? context.fetch(descriptor))?.first?.toShop()
    }

    func clearExpiredShops() {
        let now = Date()
        let descriptor = FetchDescriptor<CachedShop>(
            predicate: #Predicate { $0.expiresAt < now }
        )
        if let expired = try? context.fetch(descriptor) {
            for shop in expired {
                context.delete(shop)
            }
            try? context.save()
        }
    }

    func clearAllShops() {
        let descriptor = FetchDescriptor<CachedShop>()
        if let all = try? context.fetch(descriptor) {
            for shop in all {
                context.delete(shop)
            }
            try? context.save()
        }
    }

    // MARK: - Storage Info

    var localStoragePath: URL? {
        container.configurations.first?.url
    }

    func estimatedStorageSize() -> Int64 {
        guard let path = localStoragePath else { return 0 }
        let attributes = try? FileManager.default.attributesOfItem(atPath: path.path)
        return (attributes?[.size] as? Int64) ?? 0
    }
}

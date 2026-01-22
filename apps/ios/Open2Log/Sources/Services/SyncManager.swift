import Foundation
import Network
import Combine
import CoreLocation

/// Manages syncing pending uploads and downloading offline data
@MainActor
class SyncManager: ObservableObject {
    @Published var isOnline: Bool = false
    @Published var isWifi: Bool = false
    @Published var isSyncing: Bool = false
    @Published var lastSyncAt: Date?
    @Published var syncProgress: Double = 0
    @Published var syncError: String?

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "SyncManager")
    private var cancellables = Set<AnyCancellable>()

    private let apiClient: APIClient
    private let imageUploader: ImageUploader
    private let storage: OfflineStorage

    init(apiClient: APIClient, imageUploader: ImageUploader, storage: OfflineStorage) {
        self.apiClient = apiClient
        self.imageUploader = imageUploader
        self.storage = storage
        setupNetworkMonitoring()
    }

    private func setupNetworkMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.isOnline = path.status == .satisfied
                self?.isWifi = path.usesInterfaceType(.wifi)

                // Auto-sync when coming online
                if path.status == .satisfied {
                    self?.attemptSync()
                }
            }
        }
        monitor.start(queue: queue)
    }

    func attemptSync() {
        guard isOnline && !isSyncing else { return }

        // Check wifi-only setting
        let wifiOnly = UserDefaults.standard.bool(forKey: "syncOnWifiOnly")
        if wifiOnly && !isWifi {
            return
        }

        Task {
            await performSync()
        }
    }

    func forceSync() async {
        guard isOnline else {
            syncError = "No network connection"
            return
        }
        await performSync()
    }

    private func performSync() async {
        isSyncing = true
        syncError = nil
        syncProgress = 0
        defer {
            isSyncing = false
            syncProgress = 1.0
        }

        let pendingUploads = storage.getRetryablePendingUploads()
        guard !pendingUploads.isEmpty else {
            lastSyncAt = Date()
            return
        }

        let totalItems = pendingUploads.count
        var completed = 0

        for upload in pendingUploads {
            do {
                try await syncPendingUpload(upload)
                completed += 1
                syncProgress = Double(completed) / Double(totalItems)
            } catch {
                storage.markUploadFailed(upload, error: error.localizedDescription)
            }
        }

        // Clean up completed uploads
        storage.clearCompletedUploads()
        lastSyncAt = Date()
    }

    private func syncPendingUpload(_ upload: PendingUpload) async throws {
        // 1. Upload barcode image if exists and not uploaded
        var barcodeUrl: String?
        if let path = upload.barcodeImagePath, !upload.barcodeImageUploaded {
            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            barcodeUrl = try await imageUploader.uploadImage(data, type: .barcode)
            upload.barcodeImageUploaded = true
        }

        // 2. Upload price image if exists and not uploaded
        var priceUrl: String?
        if let path = upload.priceImagePath, !upload.priceImageUploaded {
            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            priceUrl = try await imageUploader.uploadImage(data, type: .price)
            upload.priceImageUploaded = true
        }

        // 3. Upload product image if exists and not uploaded
        var productUrl: String?
        if let path = upload.productImagePath, !upload.productImageUploaded {
            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            productUrl = try await imageUploader.uploadImage(data, type: .product)
            upload.productImageUploaded = true
        }

        // 4. Submit the price data
        if !upload.dataUploaded {
            try await apiClient.submitPrice(
                ean: upload.ean,
                productName: upload.productName,
                priceCents: upload.priceCents,
                shopGersId: upload.shopGersId,
                scannedAt: upload.scannedAt,
                barcodeImageUrl: barcodeUrl,
                priceImageUrl: priceUrl,
                productImageUrl: productUrl
            )
            storage.markUploadComplete(upload)
        }
    }

    // MARK: - Download Offline Data

    func downloadOfflineData(for location: CLLocationCoordinate2D, radiusKm: Double) async throws {
        guard isOnline else {
            throw SyncError.noNetwork
        }

        // 1. Download nearby shops
        let shops = try await apiClient.getNearbyShops(
            latitude: location.latitude,
            longitude: location.longitude,
            radiusKm: radiusKm
        )
        storage.cacheShops(shops)

        // 2. Download products for those shops
        // (Could be implemented based on common products at each shop)

        // 3. Weather data would be fetched separately if needed

        // 4. Navigation tiles (Valhalla) - would need separate service
    }

    func clearOfflineData() {
        storage.clearAllShops()
        // Don't clear pending uploads - those should be preserved
    }
}

enum SyncError: LocalizedError {
    case noNetwork
    case uploadFailed(String)
    case downloadFailed(String)

    var errorDescription: String? {
        switch self {
        case .noNetwork:
            return "No network connection available"
        case .uploadFailed(let reason):
            return "Upload failed: \(reason)"
        case .downloadFailed(let reason):
            return "Download failed: \(reason)"
        }
    }
}

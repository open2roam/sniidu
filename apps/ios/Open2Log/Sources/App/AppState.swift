import Foundation
import Combine

/// Global application state
@MainActor
class AppState: ObservableObject {
    @Published var isAuthenticated: Bool = false
    @Published var currentUser: User?
    @Published var userStatus: UserStatus = .waitlist
    @Published var isOnboarded: Bool = false

    // Settings
    @Published var syncOnWifiOnly: Bool = true
    @Published var offlineDataRadius: Double = 5.0 // km

    // Current shop detection
    @Published var currentShop: Shop?

    // Services
    let apiClient: APIClient
    let imageUploader: ImageUploader
    var offlineStorage: OfflineStorage?
    var syncManager: SyncManager?

    private let defaults = UserDefaults.standard
    private var cancellables = Set<AnyCancellable>()

    init() {
        apiClient = APIClient()
        imageUploader = ImageUploader(apiClient: apiClient)

        loadSettings()
        setupOfflineStorage()
    }

    private func setupOfflineStorage() {
        do {
            offlineStorage = try OfflineStorage()
            if let storage = offlineStorage {
                syncManager = SyncManager(
                    apiClient: apiClient,
                    imageUploader: imageUploader,
                    storage: storage
                )

                // Observe pending uploads count
                storage.$pendingUploadsCount
                    .receive(on: DispatchQueue.main)
                    .sink { [weak self] _ in
                        self?.objectWillChange.send()
                    }
                    .store(in: &cancellables)
            }
        } catch {
            print("Failed to initialize offline storage: \(error)")
        }
    }

    var pendingUploads: Int {
        offlineStorage?.pendingUploadsCount ?? 0
    }

    func loadSettings() {
        isAuthenticated = defaults.bool(forKey: "isAuthenticated")
        syncOnWifiOnly = defaults.bool(forKey: "syncOnWifiOnly")
        offlineDataRadius = defaults.double(forKey: "offlineDataRadius")
        if offlineDataRadius == 0 { offlineDataRadius = 5.0 }

        // Load auth token
        if let token = defaults.string(forKey: "authToken") {
            apiClient.setAuthToken(token)
        }
    }

    func saveSettings() {
        defaults.set(isAuthenticated, forKey: "isAuthenticated")
        defaults.set(syncOnWifiOnly, forKey: "syncOnWifiOnly")
        defaults.set(offlineDataRadius, forKey: "offlineDataRadius")
    }

    func login(token: String, user: User) {
        isAuthenticated = true
        currentUser = user
        userStatus = UserStatus(from: user)
        apiClient.setAuthToken(token)
        defaults.set(token, forKey: "authToken")
        saveSettings()
    }

    func logout() {
        isAuthenticated = false
        currentUser = nil
        userStatus = .waitlist
        defaults.removeObject(forKey: "authToken")
        saveSettings()
    }
}

enum UserStatus: String, Codable {
    case waitlist
    case active
    case member // NGO member with shopping list access

    init(from user: User) {
        switch user.membershipStatus {
        case "active":
            self = .member
        case "none":
            // Check user status from other field if available
            self = .active
        default:
            self = .waitlist
        }
    }
}

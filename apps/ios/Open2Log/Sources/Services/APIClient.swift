import Foundation

/// API client for communicating with the open2log backend
class APIClient {
    private let baseURL: URL
    private let session: URLSession
    private var authToken: String?

    init(baseURL: URL = URL(string: "https://api.open2log.com/api/v1")!) {
        self.baseURL = baseURL
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        self.session = URLSession(configuration: config)
    }

    func setAuthToken(_ token: String) {
        self.authToken = token
    }

    // MARK: - Auth

    func register(email: String, password: String) async throws -> AuthResponse {
        let body = ["email": email, "password": password]
        return try await post("/auth/register", body: body)
    }

    func login(email: String, password: String) async throws -> AuthResponse {
        let body = ["email": email, "password": password]
        return try await post("/auth/login", body: body)
    }

    // MARK: - Products

    func searchProducts(query: String, limit: Int = 20) async throws -> [Product] {
        return try await get("/products", query: ["q": query, "limit": String(limit)])
    }

    func getProduct(id: UUID) async throws -> Product {
        return try await get("/products/\(id)")
    }

    // MARK: - Shops

    func getNearbyShops(latitude: Double, longitude: Double, radiusKm: Double = 5) async throws -> [Shop] {
        return try await get("/shops/nearby", query: [
            "lat": String(latitude),
            "lon": String(longitude),
            "radius": String(radiusKm)
        ])
    }

    // MARK: - Prices

    func submitPrice(_ request: PriceSubmission) async throws -> Price {
        return try await post("/prices", body: request)
    }

    func submitPrice(
        ean: String?,
        productName: String?,
        priceCents: Int,
        shopGersId: String,
        scannedAt: Date,
        barcodeImageUrl: String?,
        priceImageUrl: String?,
        productImageUrl: String?
    ) async throws {
        let body: [String: Any?] = [
            "ean": ean,
            "product_name": productName,
            "price_cents": priceCents,
            "shop_gers_id": shopGersId,
            "scanned_at": ISO8601DateFormatter().string(from: scannedAt),
            "barcode_image_url": barcodeImageUrl,
            "price_image_url": priceImageUrl,
            "product_image_url": productImageUrl
        ]

        var request = URLRequest(url: baseURL.appendingPathComponent("/prices"))
        request.httpMethod = "POST"
        request.httpBody = try JSONSerialization.data(withJSONObject: body.compactMapValues { $0 })
        addHeaders(to: &request)

        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }
    }

    func getUploadUrl(filename: String, contentType: String, uploadType: String) async throws -> UploadUrlResponse {
        return try await post("/prices/upload_url", body: [
            "filename": filename,
            "content_type": contentType,
            "upload_type": uploadType
        ])
    }

    // MARK: - User

    func getCurrentUser() async throws -> User {
        return try await get("/me")
    }

    // MARK: - HTTP Helpers

    private func get<T: Decodable>(_ path: String, query: [String: String] = [:]) async throws -> T {
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: true)!
        if !query.isEmpty {
            components.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        }

        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        addHeaders(to: &request)

        return try await execute(request)
    }

    private func post<T: Decodable, B: Encodable>(_ path: String, body: B) async throws -> T {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.httpBody = try JSONEncoder().encode(body)
        addHeaders(to: &request)

        return try await execute(request)
    }

    private func addHeaders(to request: inout URLRequest) {
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
    }

    private func execute<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw APIError.serverError(errorResponse.error)
            }
            throw APIError.httpError(httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(T.self, from: data)
    }
}

// MARK: - Supporting Types

struct AuthResponse: Codable {
    let token: String
    let user: User
}

struct PriceSubmission: Codable {
    let productId: UUID?
    let ean: String?
    let shopId: UUID
    let priceCents: Int
    let barcodeImageUrl: String?
    let priceImageUrl: String?
    let scannedAt: Date

    enum CodingKeys: String, CodingKey {
        case productId = "product_id"
        case ean
        case shopId = "shop_id"
        case priceCents = "price_cents"
        case barcodeImageUrl = "barcode_image_url"
        case priceImageUrl = "price_image_url"
        case scannedAt = "scanned_at"
    }
}

struct UploadUrlResponse: Codable {
    let uploadUrl: String
    let publicUrl: String
    let expiresAt: Int64

    enum CodingKeys: String, CodingKey {
        case uploadUrl = "upload_url"
        case publicUrl = "public_url"
        case expiresAt = "expires_at"
    }
}

struct ErrorResponse: Codable {
    let error: String
}

enum APIError: Error, LocalizedError {
    case invalidResponse
    case httpError(Int)
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .serverError(let message):
            return message
        }
    }
}

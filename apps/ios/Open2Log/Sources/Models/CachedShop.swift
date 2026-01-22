import Foundation
import SwiftData
import CoreLocation

/// Cached shop data for offline use - stored in SwiftData
@Model
final class CachedShop {
    @Attribute(.unique) var id: UUID
    var gersId: String?
    var name: String
    var chain: String
    var address: String
    var city: String
    var postalCode: String
    var country: String
    var latitude: Double
    var longitude: Double
    var h3Index: String?
    var openingHoursJson: String?
    var cachedAt: Date
    var expiresAt: Date

    init(from shop: Shop, cacheDuration: TimeInterval = 7 * 24 * 3600) {
        self.id = shop.id
        self.gersId = shop.gersId
        self.name = shop.name
        self.chain = shop.chain.rawValue
        self.address = shop.address
        self.city = shop.city
        self.postalCode = shop.postalCode
        self.country = shop.country
        self.latitude = shop.latitude
        self.longitude = shop.longitude
        self.h3Index = shop.h3Index
        self.cachedAt = Date()
        self.expiresAt = Date().addingTimeInterval(cacheDuration)

        if let hours = shop.openingHours {
            self.openingHoursJson = try? String(data: JSONEncoder().encode(hours), encoding: .utf8)
        }
    }

    var isExpired: Bool {
        Date() > expiresAt
    }

    func toShop() -> Shop {
        var openingHours: [String: String]?
        if let json = openingHoursJson,
           let data = json.data(using: .utf8) {
            openingHours = try? JSONDecoder().decode([String: String].self, from: data)
        }

        return Shop(
            id: id,
            gersId: gersId,
            name: name,
            chain: ShopChain(rawValue: chain) ?? .other,
            address: address,
            city: city,
            postalCode: postalCode,
            country: country,
            latitude: latitude,
            longitude: longitude,
            h3Index: h3Index,
            openingHours: openingHours
        )
    }

    var location: CLLocation {
        CLLocation(latitude: latitude, longitude: longitude)
    }

    func distance(from location: CLLocation) -> CLLocationDistance {
        self.location.distance(from: location)
    }
}

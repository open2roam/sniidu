import Foundation

struct User: Codable, Identifiable {
    let id: UUID
    let email: String
    let status: String?
    let membershipStatus: String
    let memberSince: Date?
    let bankReference: String?
    let insertedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, email, status
        case membershipStatus = "membership_status"
        case memberSince = "member_since"
        case bankReference = "bank_reference"
        case insertedAt = "inserted_at"
    }
}

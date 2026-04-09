import Foundation

struct APIResponse<T: Codable>: Codable {
    let code: Int
    let message: String
    let data: T?
}

struct PageData<T: Codable>: Codable {
    let items: [T]
    let page: Int
    let pageSize: Int
    let hasMore: Bool
}

struct FeedRaw: Codable {
    let type: String
    let data: JSONValue
}

enum FeedItem: Codable {
    case text(TextCard)
    case image(ImageCard)
    case action(ActionCard)
    case profile(ProfileCard)

    enum CodingKeys: String, CodingKey {
        case type
        case data
    }

    enum ItemType: String, Codable {
        case text
        case image
        case action
        case profile
    }

    init(from decoder: Decoder) throws {
        self = try Self.decode(from: decoder)
    }
}

struct TextCard: Codable {
    let id: Int
    let title: String
    let subtitle: String?
}

struct ImageCard: Codable {
    let id: Int
    let title: String
    let imageUrl: String
}

struct ActionCard: Codable {
    let id: Int
    let title: String
    let buttonTitle: String
}

struct ProfileCard: Codable {
    let id: Int
    let name: String
    let intro: String
    let followTitle: String
    let messageTitle: String
}

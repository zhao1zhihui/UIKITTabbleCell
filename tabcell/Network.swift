import Foundation

enum FeedAPI {
    case feed(page: Int, pageSize: Int)
}

final class NetworkService {
    static let shared = NetworkService()

    private init() {}

    func request(_ target: FeedAPI) async -> APIResult<Data> {
        guard !Task.isCancelled else {
            return .failure(.cancelled)
        }
        _ = target
        return .success(LocalFeedDataStore.data)
    }
}

private struct LocalFeedEnvelope<Item: Codable>: Codable {
    let code: Int
    let message: String
    let data: LocalFeedPage<Item>?
}

private struct LocalFeedPage<Item: Codable>: Codable {
    let items: [Item]
}

final class FeedRepository {
    func fetchFeed(page: Int, pageSize: Int) async -> APIResult<PageResult<FeedItem>> {
        let result = await NetworkService.shared.request(.feed(page: page, pageSize: pageSize))
        switch result {
        case .success(let data):
            return makePageResult(from: data, itemType: FeedItem.self, page: page, pageSize: pageSize)
        case .failure(let error):
            return .failure(error)
        }
    }

    func fetchFeedRaw(page: Int, pageSize: Int) async -> APIResult<PageResult<FeedRaw>> {
        let result = await NetworkService.shared.request(.feed(page: page, pageSize: pageSize))
        switch result {
        case .success(let data):
            return makePageResult(from: data, itemType: FeedRaw.self, page: page, pageSize: pageSize)
        case .failure(let error):
            return .failure(error)
        }
    }

    private func makePageResult<Item: Codable>(from data: Data,
                                               itemType: Item.Type,
                                               page: Int,
                                               pageSize: Int) -> APIResult<PageResult<Item>> {
        do {
            _ = itemType
            let response = try JSONDecoder().decode(LocalFeedEnvelope<Item>.self, from: data)
            guard response.code == 0 else {
                return .failure(.server(code: response.code, message: response.message))
            }
            guard let allItems = response.data?.items else {
                return .failure(.emptyData)
            }
            let startIndex = page * pageSize
            guard startIndex < allItems.count else {
                return .success(PageResult(items: [], page: page, pageSize: pageSize, hasMore: false))
            }
            let endIndex = min(startIndex + pageSize, allItems.count)
            let pagedItems = Array(allItems[startIndex..<endIndex])
            return .success(
                PageResult(
                    items: pagedItems,
                    page: page,
                    pageSize: pageSize,
                    hasMore: endIndex < allItems.count
                )
            )
        } catch {
            return .failure(.decoding(error))
        }
    }
}

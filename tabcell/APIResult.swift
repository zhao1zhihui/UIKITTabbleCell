import Foundation

enum APIError: Error {
    case network(Error)
    case decoding(Error)
    case emptyData
    case server(code: Int, message: String)
    case cancelled
    case unknown(String)

    var message: String {
        switch self {
        case .network(let error):
            return error.localizedDescription
        case .decoding(let error):
            return "数据解析失败: \(error.localizedDescription)"
        case .emptyData:
            return "暂无数据"
        case .server(_, let message):
            return message
        case .cancelled:
            return "请求已取消"
        case .unknown(let message):
            return message
        }
    }
}

enum APIResult<Value> {
    case success(Value)
    case failure(APIError)

    func map<T>(_ transform: (Value) -> T) -> APIResult<T> {
        switch self {
        case .success(let value):
            return .success(transform(value))
        case .failure(let error):
            return .failure(error)
        }
    }
}

struct PageResult<Item> {
    let items: [Item]
    let page: Int
    let pageSize: Int
    let hasMore: Bool

    func mapItems<T>(_ transform: (Item) -> T) -> PageResult<T> {
        PageResult<T>(items: items.map(transform), page: page, pageSize: pageSize, hasMore: hasMore)
    }
}

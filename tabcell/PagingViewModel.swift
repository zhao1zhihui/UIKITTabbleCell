import Foundation

struct PagingState {
    var page: Int = 0
    var pageSize: Int = 10
    var hasMore: Bool = true
}

protocol PagingViewModel: AnyObject {
    associatedtype Item
    var items: [Item] { get set }
    var paging: PagingState { get set }
    func fetch(page: Int, pageSize: Int) async -> APIResult<PageResult<Item>>
}

extension PagingViewModel {
    @discardableResult
    func refresh() async -> APIResult<[Item]> {
        paging.page = 0
        let result = await fetch(page: paging.page, pageSize: paging.pageSize)
        guard !Task.isCancelled else { return .failure(.cancelled) }
        switch result {
        case .success(let pageResult):
            items = pageResult.items
            paging.hasMore = pageResult.hasMore
            return .success(items)
        case .failure(let error):
            return .failure(error)
        }
    }

    @discardableResult
    func loadMore() async -> APIResult<[Item]> {
        guard paging.hasMore else { return .success(items) }
        let nextPage = paging.page + 1
        let result = await fetch(page: nextPage, pageSize: paging.pageSize)
        guard !Task.isCancelled else { return .failure(.cancelled) }
        switch result {
        case .success(let pageResult):
            paging.page = nextPage
            items.append(contentsOf: pageResult.items)
            paging.hasMore = pageResult.hasMore
            return .success(items)
        case .failure(let error):
            return .failure(error)
        }
    }
}

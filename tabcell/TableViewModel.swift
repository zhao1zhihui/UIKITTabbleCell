import UIKit

final class TableViewModel: PagingViewModel {
    typealias Item = AnyTableItem

    private let provider: TableItemProvider
    var items: [AnyTableItem] = []
    var paging: PagingState

    init(provider: TableItemProvider = EnumTableItemProvider(), pageSize: Int = 10) {
        self.provider = provider
        self.paging = PagingState(page: 0, pageSize: pageSize, hasMore: true)
    }

    func fetch(page: Int, pageSize: Int) async -> APIResult<PageResult<AnyTableItem>> {
        await provider.loadItems(page: page, pageSize: pageSize)
    }
}

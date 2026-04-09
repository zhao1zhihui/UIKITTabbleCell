import UIKit
import KafkaRefresh

protocol TableRefreshControlling: AnyObject {
    func bind()
}

final class TableRefreshController: TableRefreshControlling {
    private weak var tableView: UITableView?
    private let onRefresh: () async -> Void
    private let onLoadMore: () async -> Void
    private let hasMore: () -> Bool
    private var isRefreshing = false
    private var isLoadingMore = false
    private var refreshTask: Task<Void, Never>?
    private var loadMoreTask: Task<Void, Never>?

    init(tableView: UITableView,
         onRefresh: @escaping () async -> Void,
         onLoadMore: @escaping () async -> Void,
         hasMore: @escaping () -> Bool) {
        self.tableView = tableView
        self.onRefresh = onRefresh
        self.onLoadMore = onLoadMore
        self.hasMore = hasMore
    }

    func bind() {
        tableView?.bindGlobalStyle(forHeadRefreshHandler: { [weak self] in
            self?.triggerRefresh()
        })
        tableView?.bindGlobalStyle(forFootRefreshHandler: { [weak self] in
            self?.triggerLoadMore()
        })
        tableView?.footRefreshControl?.autoRefreshOnFoot = true
    }

    private func triggerRefresh() {
        guard !isRefreshing, !isLoadingMore else {
            tableView?.headRefreshControl?.endRefreshing()
            return
        }
        isRefreshing = true
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            guard let self else { return }
            await self.onRefresh()
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self.isRefreshing = false
                self.tableView?.headRefreshControl?.endRefreshing()
                self.tableView?.footRefreshControl?.endRefreshing()
            }
        }
    }

    private func triggerLoadMore() {
        guard !isLoadingMore, !isRefreshing else {
            tableView?.footRefreshControl?.endRefreshing()
            return
        }
        guard hasMore() else {
            tableView?.footRefreshControl?.endRefreshing()
            return
        }
        isLoadingMore = true
        loadMoreTask?.cancel()
        loadMoreTask = Task { [weak self] in
            guard let self else { return }
            await self.onLoadMore()
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self.isLoadingMore = false
                self.tableView?.footRefreshControl?.endRefreshing()
            }
        }
    }

    deinit {
        refreshTask?.cancel()
        loadMoreTask?.cancel()
    }
}

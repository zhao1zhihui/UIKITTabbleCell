import Foundation

protocol TableItemProvider {
    func loadItems(page: Int, pageSize: Int) async -> APIResult<PageResult<AnyTableItem>>
}

final class EnumTableItemProvider: TableItemProvider {
    private let repository = FeedRepository()
    private let textCallbacks: TextCellCallbacks?
    private let imageEventHandler: ImageCellEventHandler?
    private weak var actionDelegate: ActionCardCellDelegate?
    private weak var profileDelegate: ProfileCardCellDelegate?

    init(textCallbacks: TextCellCallbacks? = nil,
         imageEventHandler: ImageCellEventHandler? = nil,
         actionDelegate: ActionCardCellDelegate? = nil,
         profileDelegate: ProfileCardCellDelegate? = nil) {
        self.textCallbacks = textCallbacks
        self.imageEventHandler = imageEventHandler
        self.actionDelegate = actionDelegate
        self.profileDelegate = profileDelegate
    }

    func loadItems(page: Int, pageSize: Int) async -> APIResult<PageResult<AnyTableItem>> {
        let result = await repository.fetchFeed(page: page, pageSize: pageSize)
        return result.map { pageResult in
            pageResult.mapItems { item in
                switch item {
                case .text:
                    return item.makeTextTableItem(textCallbacks: textCallbacks)
                case .image:
                    return item.makeImageTableItem(imageEventHandler: imageEventHandler)
                case .action:
                    return item.makeActionTableItem(actionDelegate: actionDelegate)
                case .profile:
                    return item.makeProfileTableItem(profileDelegate: profileDelegate)
                }
            }
        }
    }
}

final class RegistryTableItemProvider: TableItemProvider {
    private let repository = FeedRepository()
    private let registry: TableItemRegistry

    init(registry: TableItemRegistry = TableItemRegistry()) {
        self.registry = registry
    }

    convenience init(textCallbacks: TextCellCallbacks? = nil,
                     imageEventHandler: ImageCellEventHandler? = nil,
                     actionDelegate: ActionCardCellDelegate? = nil,
                     profileDelegate: ProfileCardCellDelegate? = nil) {
        self.init(
            registry: TableItemRegistry(
                textCallbacks: textCallbacks,
                imageEventHandler: imageEventHandler,
                actionDelegate: actionDelegate,
                profileDelegate: profileDelegate
            )
        )
    }

    func loadItems(page: Int, pageSize: Int) async -> APIResult<PageResult<AnyTableItem>> {
        let result = await repository.fetchFeedRaw(page: page, pageSize: pageSize)
        return result.map { pageResult in
            let mapped = pageResult.items.compactMap { registry.makeItem(from: $0) }
            return PageResult(items: mapped, page: pageResult.page, pageSize: pageResult.pageSize, hasMore: pageResult.hasMore)
        }
    }
}

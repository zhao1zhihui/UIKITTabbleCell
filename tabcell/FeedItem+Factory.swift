import Foundation

extension FeedItem {
    static func decode(from decoder: Decoder) throws -> FeedItem {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(ItemType.self, forKey: .type)
        switch type {
        case .text:
            return .text(try container.decode(TextCard.self, forKey: .data))
        case .image:
            return .image(try container.decode(ImageCard.self, forKey: .data))
        case .action:
            return .action(try container.decode(ActionCard.self, forKey: .data))
        case .profile:
            return .profile(try container.decode(ProfileCard.self, forKey: .data))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text(let value):
            try container.encode(ItemType.text, forKey: .type)
            try container.encode(value, forKey: .data)
        case .image(let value):
            try container.encode(ItemType.image, forKey: .type)
            try container.encode(value, forKey: .data)
        case .action(let value):
            try container.encode(ItemType.action, forKey: .type)
            try container.encode(value, forKey: .data)
        case .profile(let value):
            try container.encode(ItemType.profile, forKey: .type)
            try container.encode(value, forKey: .data)
        }
    }

    func makeTextTableItem(textCallbacks: TextCellCallbacks? = nil) -> AnyTableItem {
        guard case .text(let model) = self else {
            preconditionFailure("makeTextTableItem can only be used with .text")
        }
        let row = TextRowModel(
            dto: model,
            onTapTitle: {
                textCallbacks?.onTitleTap?(model.id)
            },
            onTapSubtitle: {
                textCallbacks?.onSubtitleTap?(model.id)
            }
        )
        return AnyTableItem(TextCardCell.self, model: row, heightProvider: { width in
            row.height(for: width)
        })
    }

    func makeImageTableItem(imageEventHandler: ImageCellEventHandler? = nil) -> AnyTableItem {
        guard case .image(let model) = self else {
            preconditionFailure("makeImageTableItem can only be used with .image")
        }
        let row = ImageRowModel(dto: model, onEvent: { event in
            imageEventHandler?.onEvent?(model.id, event)
        })
        return AnyTableItem(ImageCardCell.self, model: row, heightProvider: { width in
            row.height(for: width)
        })
    }

    func makeActionTableItem(actionDelegate: ActionCardCellDelegate? = nil) -> AnyTableItem {
        guard case .action(let model) = self else {
            preconditionFailure("makeActionTableItem can only be used with .action")
        }
        let row = ActionRowModel(dto: model)
        return AnyTableItem(ActionCardCell.self, model: row, inject: { [weak actionDelegate] cell in
            cell.delegate = actionDelegate
        })
    }

    func makeProfileTableItem(profileDelegate: ProfileCardCellDelegate? = nil) -> AnyTableItem {
        guard case .profile(let model) = self else {
            preconditionFailure("makeProfileTableItem can only be used with .profile")
        }
        let row = ProfileRowModel(dto: model)
        return AnyTableItem(ProfileCardCell.self, model: row, inject: { [weak profileDelegate] cell in
            cell.delegate = profileDelegate
        })
    }
}

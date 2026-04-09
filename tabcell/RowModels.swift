import UIKit

enum ImageRowEvent {
    case tapTitle
    case tapImage
    case tapURL
}

final class TextRowModel: RowLayoutProviding, RowLayoutSpecProviding {
    let id: Int
    let title: String
    let subtitle: String?
    let onTapTitle: (() -> Void)?
    let onTapSubtitle: (() -> Void)?

    let titleAttr: NSAttributedString
    let subtitleAttr: NSAttributedString?

    var titleHeight: CGFloat = 0
    var subtitleHeight: CGFloat = 0

    struct LayoutSpec {
        let titleWidth: CGFloat
        let subtitleWidth: CGFloat
    }

    static let layout = LayoutSpec(
        titleWidth: UIScreen.screenWidth - Layout.horizontalPadding * 2,
        subtitleWidth: UIScreen.screenWidth - Layout.horizontalPadding * 2
    )

    init(dto: TextCard,
         onTapTitle: (() -> Void)? = nil,
         onTapSubtitle: (() -> Void)? = nil) {
        self.id = dto.id
        self.title = dto.title
        self.subtitle = dto.subtitle
        self.onTapTitle = onTapTitle
        self.onTapSubtitle = onTapSubtitle
        self.titleAttr = TableTextStyles.title.makeAttributed(dto.title)
        if let subtitle = dto.subtitle {
            self.subtitleAttr = TableTextStyles.subtitle.makeAttributed(subtitle)
        } else {
            self.subtitleAttr = nil
        }
    }

    func height(for width: CGFloat) -> CGFloat {
        var total = Layout.verticalPadding
        titleHeight = TableTextStyles.title.height(for: title, width: Self.layout.titleWidth)
        total += titleHeight
        if let subtitle = subtitle {
            total += Layout.interItemSpacing
            subtitleHeight = TableTextStyles.subtitle.height(for: subtitle, width: Self.layout.subtitleWidth)
            total += subtitleHeight
        } else {
            subtitleHeight = 0
        }
        total += Layout.verticalPadding
        return total
    }
}

final class ImageRowModel: RowLayoutProviding, RowLayoutSpecProviding {
    let id: Int
    let title: String
    let imageUrl: String
    let onEvent: ((ImageRowEvent) -> Void)?

    let titleAttr: NSAttributedString
    var titleHeight: CGFloat = 0
    var urlHeight: CGFloat = 0

    struct LayoutSpec {
        let titleWidth: CGFloat
        let urlWidth: CGFloat
        let coverWidth: CGFloat
    }

    static let layout = LayoutSpec(
        titleWidth: UIScreen.screenWidth - Layout.horizontalPadding * 2,
        urlWidth: UIScreen.screenWidth - Layout.horizontalPadding * 2,
        coverWidth: UIScreen.screenWidth - Layout.horizontalPadding * 2
    )

    init(dto: ImageCard,
         onEvent: ((ImageRowEvent) -> Void)? = nil) {
        self.id = dto.id
        self.title = dto.title
        self.imageUrl = dto.imageUrl
        self.onEvent = onEvent
        self.titleAttr = TableTextStyles.title.makeAttributed(dto.title)
    }

    func height(for width: CGFloat) -> CGFloat {
        var total = Layout.verticalPadding
        titleHeight = TableTextStyles.title.height(for: title, width: Self.layout.titleWidth)
        total += titleHeight
        total += Layout.interItemSpacing
        total += Layout.imageHeight
        total += Layout.interItemSpacing
        let rawURLHeight = TableTextStyles.subtitle.height(for: imageUrl, width: Self.layout.urlWidth)
        let maxURLHeight = TableTextStyles.subtitle.lineHeight * 2
        urlHeight = min(rawURLHeight, maxURLHeight)
        total += urlHeight
        total += Layout.verticalPadding
        return total
    }
}

final class ActionRowModel {
    let id: Int
    let title: String
    let buttonTitle: String

    let titleAttr: NSAttributedString

    init(dto: ActionCard) {
        self.id = dto.id
        self.title = dto.title
        self.buttonTitle = dto.buttonTitle
        self.titleAttr = TableTextStyles.title.makeAttributed(dto.title)
    }
}

final class ProfileRowModel {
    let id: Int
    let name: String
    let intro: String
    let followTitle: String
    let messageTitle: String

    let nameAttr: NSAttributedString
    let introAttr: NSAttributedString

    init(dto: ProfileCard) {
        self.id = dto.id
        self.name = dto.name
        self.intro = dto.intro
        self.followTitle = dto.followTitle
        self.messageTitle = dto.messageTitle
        self.nameAttr = TableTextStyles.title.makeAttributed(dto.name)
        self.introAttr = TableTextStyles.subtitle.makeAttributed(dto.intro)
    }
}

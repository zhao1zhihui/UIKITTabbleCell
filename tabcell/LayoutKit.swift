import UIKit

struct TextStyle {
    let font: UIFont
    let lineHeight: CGFloat
    let color: UIColor

    var attributes: [NSAttributedString.Key: Any] {
        let paragraph = NSMutableParagraphStyle()
        paragraph.minimumLineHeight = lineHeight
        paragraph.maximumLineHeight = lineHeight
        return [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraph
        ]
    }

    func makeAttributed(_ text: String) -> NSAttributedString {
        NSAttributedString(string: text, attributes: attributes)
    }

    func height(for text: String, width: CGFloat) -> CGFloat {
        let attr = makeAttributed(text)
        let rect = attr.boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        return ceil(rect.height)
    }
}

extension UIScreen {
    static var screenWidth: CGFloat {
        main.bounds.width
    }
}

enum TableTextStyles {
    static let title = TextStyle(font: .systemFont(ofSize: 16, weight: .semibold),
                                 lineHeight: 22,
                                 color: .label)
    static let subtitle = TextStyle(font: .systemFont(ofSize: 13, weight: .regular),
                                    lineHeight: 18,
                                    color: .secondaryLabel)
}

protocol RowLayoutSpecProviding {
    associatedtype LayoutSpec
    static var layout: LayoutSpec { get }
}

enum Layout {
    static let horizontalPadding: CGFloat = 16
    static let verticalPadding: CGFloat = 12
    static let interItemSpacing: CGFloat = 6
    static let imageHeight: CGFloat = 64
    static let buttonHeight: CGFloat = 36
}

protocol RowLayoutProviding {
    func height(for width: CGFloat) -> CGFloat
}

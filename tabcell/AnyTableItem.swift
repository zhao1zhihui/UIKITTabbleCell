import UIKit

protocol TableCellConfigurable: UITableViewCell {
    associatedtype Model
    static var reuseID: String { get }
    func bind(_ model: Model)
}

extension TableCellConfigurable {
    static var reuseID: String { String(describing: Self.self) }
}

struct AnyTableItem {
    let reuseID: String
    let cellClass: UITableViewCell.Type
    let configure: (UITableViewCell) -> Void
    let heightProvider: ((CGFloat) -> CGFloat)?

    init<C: TableCellConfigurable>(_ cellType: C.Type,
                                   model: C.Model,
                                   heightProvider: ((CGFloat) -> CGFloat)? = nil,
                                   inject: ((C) -> Void)? = nil) {
        self.reuseID = cellType.reuseID
        self.cellClass = cellType
        self.configure = { cell in
            if let typed = cell as? C {
                typed.bind(model)
                inject?(typed)
            }
        }
        self.heightProvider = heightProvider
    }
}

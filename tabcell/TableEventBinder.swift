import Foundation

struct TextCellCallbacks {
    var onTitleTap: ((Int) -> Void)?
    var onSubtitleTap: ((Int) -> Void)?
}

struct ImageCellEventHandler {
    var onEvent: ((Int, ImageRowEvent) -> Void)?
}

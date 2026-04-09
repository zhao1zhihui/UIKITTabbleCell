import Foundation

/// 注册表模式的核心：
/// 把后端返回的 `type` 字符串，映射成“如何解码 + 如何组装 AnyTableItem”的一组规则。
final class TableItemRegistry {
    /// key = 后端 type，value = 把原始 JSON 转成 AnyTableItem 的构建闭包
    typealias Builder = (JSONValue) -> AnyTableItem?
    private var builders: [String: Builder] = [:]

    init(textCallbacks: TextCellCallbacks? = nil,
         imageEventHandler: ImageCellEventHandler? = nil,
         actionDelegate: ActionCardCellDelegate? = nil,
         profileDelegate: ProfileCardCellDelegate? = nil) {
        // 初始化时先把项目里默认支持的卡片类型注册进去
        registerDefaults(
            textCallbacks: textCallbacks,
            imageEventHandler: imageEventHandler,
            actionDelegate: actionDelegate,
            profileDelegate: profileDelegate
        )
    }

    /// 最底层注册入口：直接传一个 builder 进来
    func register(_ type: String, builder: @escaping Builder) {
        builders[type] = builder
    }

    /// 通用注册入口：
    /// 1. 先把 JSONValue 解码成具体 DTO
    /// 2. 再把 DTO 映射成 cell 需要的 RowModel
    /// 3. 最后包装成 AnyTableItem 给列表消费
    func register<T: Decodable, C: TableCellConfigurable>(_ type: String,
                                                          dto: T.Type,
                                                          cell: C.Type,
                                                          map: @escaping (T) -> C.Model,
                                                          inject: ((C) -> Void)? = nil) {
        register(type) { value in
            guard let dto = Self.decode(T.self, from: value) else { return nil }
            let model = map(dto)
            let heightProvider: ((CGFloat) -> CGFloat)?
            if let layout = model as? RowLayoutProviding {
                // 支持预计算高度的 rowModel，继续把测高能力透传给 AnyTableItem
                heightProvider = { width in layout.height(for: width) }
            } else {
                // 像 Action 这种走 automaticDimension 的 cell，就不需要 heightProvider
                heightProvider = nil
            }
            return AnyTableItem(cell, model: model, heightProvider: heightProvider, inject: inject)
        }
    }

    /// 列表真正消费的入口：根据后端 type 找到对应 builder
    func makeItem(from raw: FeedRaw) -> AnyTableItem? {
        builders[raw.type]?(raw.data)
    }

    private func registerDefaults(textCallbacks: TextCellCallbacks?,
                                  imageEventHandler: ImageCellEventHandler?,
                                  actionDelegate: ActionCardCellDelegate?,
                                  profileDelegate: ProfileCardCellDelegate?) {
        // text: DTO -> TextRowModel，并把两个点击事件组装进 rowModel
        register("text", dto: TextCard.self, cell: TextCardCell.self) { dto in
            TextRowModel(
                dto: dto,
                onTapTitle: {
                    textCallbacks?.onTitleTap?(dto.id)
                },
                onTapSubtitle: {
                    textCallbacks?.onSubtitleTap?(dto.id)
                }
            )
        }
        // image: DTO -> ImageRowModel，并把 enum 事件回调组装进去
        register("image", dto: ImageCard.self, cell: ImageCardCell.self) { dto in
            ImageRowModel(dto: dto, onEvent: { event in
                imageEventHandler?.onEvent?(dto.id, event)
            })
        }
        // action: DTO -> ActionRowModel，delegate 不进 rowModel，走 cell 注入
        register("action",
                 dto: ActionCard.self,
                 cell: ActionCardCell.self,
                 map: { ActionRowModel(dto: $0) },
                 inject: { [weak actionDelegate] cell in
                     cell.delegate = actionDelegate
                 })
        // profile: DTO -> ProfileRowModel，事件全部走 delegate 注入
        register("profile",
                 dto: ProfileCard.self,
                 cell: ProfileCardCell.self,
                 map: { ProfileRowModel(dto: $0) },
                 inject: { [weak profileDelegate] cell in
                     cell.delegate = profileDelegate
                 })
    }

    /// 先把 JSONValue 编成 Data，再用 Codable 解成真正 DTO
    private static func decode<T: Decodable>(_ type: T.Type, from value: JSONValue) -> T? {
        guard let data = try? JSONEncoder().encode(value) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}

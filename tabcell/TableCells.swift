import UIKit
import SnapKit
import SDWebImage

protocol ActionCardCellDelegate: AnyObject {
    func actionCardCell(_ cell: ActionCardCell, didTapTitleWith id: Int)
    func actionCardCell(_ cell: ActionCardCell, didTapButtonWith id: Int)
}

protocol ProfileCardCellDelegate: AnyObject {
    func profileCardCell(_ cell: ProfileCardCell, didTapNameWith id: Int)
    func profileCardCell(_ cell: ProfileCardCell, didTapFollowWith id: Int)
    func profileCardCell(_ cell: ProfileCardCell, didTapMessageWith id: Int)
}

final class TextCardCell: UITableViewCell, TableCellConfigurable {
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let stack = UIStackView()
    private var currentModel: TextRowModel?
    private var titleWidthConstraint: Constraint?
    private var subtitleWidthConstraint: Constraint?
    private var titleHeightConstraint: Constraint?
    private var subtitleHeightConstraint: Constraint?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    func bind(_ model: TextRowModel) {
        currentModel = model
        titleLabel.attributedText = model.titleAttr
        subtitleLabel.attributedText = model.subtitleAttr
        subtitleLabel.isHidden = model.subtitleAttr == nil
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard let currentModel else { return }
        applyMetrics(currentModel)
    }

    private func setupUI() {
        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        titleLabel.numberOfLines = 0
        titleLabel.isUserInteractionEnabled = true
        subtitleLabel.font = .systemFont(ofSize: 13, weight: .regular)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.numberOfLines = 0
        subtitleLabel.isUserInteractionEnabled = true

        stack.axis = .vertical
        stack.alignment = .leading
        stack.addArrangedSubview(titleLabel)
        stack.addArrangedSubview(subtitleLabel)
        stack.spacing = Layout.interItemSpacing
        contentView.addSubview(stack)
        titleLabel.snp.makeConstraints { make in
            titleWidthConstraint = make.width.equalTo(0).constraint
            titleHeightConstraint = make.height.equalTo(0).constraint
        }
        subtitleLabel.snp.makeConstraints { make in
            subtitleWidthConstraint = make.width.equalTo(0).constraint
            subtitleHeightConstraint = make.height.equalTo(0).constraint
        }
        stack.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Layout.horizontalPadding)
            make.trailing.equalToSuperview().inset(Layout.horizontalPadding)
            make.top.equalToSuperview().offset(Layout.verticalPadding)
            make.bottom.equalToSuperview().inset(Layout.verticalPadding)
        }

        let titleTap = UITapGestureRecognizer(target: self, action: #selector(handleTitleTap))
        titleLabel.addGestureRecognizer(titleTap)
        let subtitleTap = UITapGestureRecognizer(target: self, action: #selector(handleSubtitleTap))
        subtitleLabel.addGestureRecognizer(subtitleTap)
    }

    private func applyMetrics(_ model: TextRowModel) {
        guard contentView.bounds.width > 0 else { return }
        _ = model.height(for: contentView.bounds.width)
        titleWidthConstraint?.update(offset: TextRowModel.layout.titleWidth)
        subtitleWidthConstraint?.update(offset: TextRowModel.layout.subtitleWidth)
        titleHeightConstraint?.update(offset: model.titleHeight)
        subtitleHeightConstraint?.update(offset: model.subtitleHeight)
    }

    @objc private func handleTitleTap() {
        currentModel?.onTapTitle?()
    }

    @objc private func handleSubtitleTap() {
        currentModel?.onTapSubtitle?()
    }
}

final class ImageCardCell: UITableViewCell, TableCellConfigurable {
    private let titleLabel = UILabel()
    private let urlLabel = UILabel()
    private let coverImageView = UIImageView()
    private let stack = UIStackView()
    private var currentModel: ImageRowModel?
    private var titleWidthConstraint: Constraint?
    private var urlWidthConstraint: Constraint?
    private var coverWidthConstraint: Constraint?
    private var titleHeightConstraint: Constraint?
    private var urlHeightConstraint: Constraint?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    func bind(_ model: ImageRowModel) {
        currentModel = model
        titleLabel.attributedText = model.titleAttr
        urlLabel.attributedText = TableTextStyles.subtitle.makeAttributed(model.imageUrl)
        if let url = URL(string: model.imageUrl), url.scheme != nil {
            coverImageView.sd_setImage(with: url, placeholderImage: nil)
        } else {
            coverImageView.image = nil
        }
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard let currentModel else { return }
        applyMetrics(currentModel)
    }

    private func setupUI() {
        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        titleLabel.numberOfLines = 0
        titleLabel.isUserInteractionEnabled = true
        urlLabel.numberOfLines = 2
        urlLabel.isUserInteractionEnabled = true

        coverImageView.backgroundColor = UIColor.systemGray5
        coverImageView.layer.cornerRadius = 8
        coverImageView.clipsToBounds = true
        coverImageView.contentMode = .scaleAspectFill
        coverImageView.isUserInteractionEnabled = true

        stack.axis = .vertical
        stack.alignment = .leading
        stack.addArrangedSubview(titleLabel)
        stack.addArrangedSubview(coverImageView)
        stack.addArrangedSubview(urlLabel)
        stack.spacing = Layout.interItemSpacing
        contentView.addSubview(stack)
        titleLabel.snp.makeConstraints { make in
            titleWidthConstraint = make.width.equalTo(0).constraint
            titleHeightConstraint = make.height.equalTo(0).constraint
        }
        urlLabel.snp.makeConstraints { make in
            urlWidthConstraint = make.width.equalTo(0).constraint
            urlHeightConstraint = make.height.equalTo(0).constraint
        }
        coverImageView.snp.makeConstraints { make in
            coverWidthConstraint = make.width.equalTo(0).constraint
        }
        stack.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Layout.horizontalPadding)
            make.trailing.equalToSuperview().inset(Layout.horizontalPadding)
            make.top.equalToSuperview().offset(Layout.verticalPadding)
            make.bottom.equalToSuperview().inset(Layout.verticalPadding)
        }
        coverImageView.snp.makeConstraints { make in
            make.height.equalTo(Layout.imageHeight)
        }

        let titleTap = UITapGestureRecognizer(target: self, action: #selector(handleImageTitleTap))
        titleLabel.addGestureRecognizer(titleTap)
        let imageTap = UITapGestureRecognizer(target: self, action: #selector(handleCoverTap))
        coverImageView.addGestureRecognizer(imageTap)
        let urlTap = UITapGestureRecognizer(target: self, action: #selector(handleURLTap))
        urlLabel.addGestureRecognizer(urlTap)
    }

    private func applyMetrics(_ model: ImageRowModel) {
        guard contentView.bounds.width > 0 else { return }
        _ = model.height(for: contentView.bounds.width)
        titleWidthConstraint?.update(offset: ImageRowModel.layout.titleWidth)
        urlWidthConstraint?.update(offset: ImageRowModel.layout.urlWidth)
        coverWidthConstraint?.update(offset: ImageRowModel.layout.coverWidth)
        titleHeightConstraint?.update(offset: model.titleHeight)
        urlHeightConstraint?.update(offset: model.urlHeight)
    }

    @objc private func handleImageTitleTap() {
        currentModel?.onEvent?(.tapTitle)
    }

    @objc private func handleCoverTap() {
        currentModel?.onEvent?(.tapImage)
    }

    @objc private func handleURLTap() {
        currentModel?.onEvent?(.tapURL)
    }
}

final class ActionCardCell: UITableViewCell, TableCellConfigurable {
    private let titleLabel = UILabel()
    private let actionButton = UIButton(type: .system)
    private let stack = UIStackView()
    private var currentModel: ActionRowModel?
    weak var delegate: ActionCardCellDelegate?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    func bind(_ model: ActionRowModel) {
        currentModel = model
        titleLabel.attributedText = model.titleAttr
        actionButton.setTitle(model.buttonTitle, for: .normal)
    }

    private func setupUI() {
        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        titleLabel.numberOfLines = 0
        titleLabel.isUserInteractionEnabled = true
        actionButton.setTitleColor(.white, for: .normal)
        actionButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .regular)
        actionButton.backgroundColor = .systemBlue
        actionButton.layer.cornerRadius = 8
        actionButton.contentEdgeInsets = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        titleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        actionButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        actionButton.setContentHuggingPriority(.required, for: .horizontal)

        stack.axis = .horizontal
        stack.addArrangedSubview(titleLabel)
        stack.addArrangedSubview(actionButton)
        stack.spacing = Layout.interItemSpacing * 2
        stack.alignment = .center
        stack.distribution = .fill

        contentView.addSubview(stack)
        stack.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Layout.horizontalPadding)
            make.trailing.equalToSuperview().inset(Layout.horizontalPadding)
            make.top.equalToSuperview().offset(Layout.verticalPadding)
            make.bottom.equalToSuperview().inset(Layout.verticalPadding)
        }
        actionButton.snp.makeConstraints { make in
            make.height.equalTo(Layout.buttonHeight)
        }

        let titleTap = UITapGestureRecognizer(target: self, action: #selector(handleActionTitleTap))
        titleLabel.addGestureRecognizer(titleTap)
        actionButton.addTarget(self, action: #selector(handleActionButtonTap), for: .touchUpInside)
    }

    @objc private func handleActionTitleTap() {
        guard let currentModel else { return }
        delegate?.actionCardCell(self, didTapTitleWith: currentModel.id)
    }

    @objc private func handleActionButtonTap() {
        guard let currentModel else { return }
        delegate?.actionCardCell(self, didTapButtonWith: currentModel.id)
    }
}

final class ProfileCardCell: UITableViewCell, TableCellConfigurable {
    private let nameLabel = UILabel()
    private let introLabel = UILabel()
    private let followButton = UIButton(type: .system)
    private let messageButton = UIButton(type: .system)
    private let buttonStack = UIStackView()
    private let contentStack = UIStackView()
    private var currentModel: ProfileRowModel?
    weak var delegate: ProfileCardCellDelegate?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    func bind(_ model: ProfileRowModel) {
        currentModel = model
        nameLabel.attributedText = model.nameAttr
        introLabel.attributedText = model.introAttr
        followButton.setTitle(model.followTitle, for: .normal)
        messageButton.setTitle(model.messageTitle, for: .normal)
    }

    private func setupUI() {
        nameLabel.numberOfLines = 0
        nameLabel.isUserInteractionEnabled = true
        introLabel.numberOfLines = 0
        introLabel.textColor = .secondaryLabel

        followButton.setTitleColor(.white, for: .normal)
        followButton.backgroundColor = .systemBlue
        followButton.layer.cornerRadius = 8
        followButton.contentEdgeInsets = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)

        messageButton.setTitleColor(.systemBlue, for: .normal)
        messageButton.backgroundColor = .systemBlue.withAlphaComponent(0.12)
        messageButton.layer.cornerRadius = 8
        messageButton.contentEdgeInsets = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)

        buttonStack.axis = .horizontal
        buttonStack.spacing = Layout.interItemSpacing * 2
        buttonStack.alignment = .fill
        buttonStack.distribution = .fillProportionally
        buttonStack.addArrangedSubview(followButton)
        buttonStack.addArrangedSubview(messageButton)

        contentStack.axis = .vertical
        contentStack.spacing = Layout.interItemSpacing
        contentStack.alignment = .fill
        contentStack.addArrangedSubview(nameLabel)
        contentStack.addArrangedSubview(introLabel)
        contentStack.addArrangedSubview(buttonStack)

        contentView.addSubview(contentStack)
        contentStack.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Layout.horizontalPadding)
            make.trailing.equalToSuperview().inset(Layout.horizontalPadding)
            make.top.equalToSuperview().offset(Layout.verticalPadding)
            make.bottom.equalToSuperview().inset(Layout.verticalPadding)
        }
        followButton.snp.makeConstraints { make in
            make.height.equalTo(Layout.buttonHeight)
        }
        messageButton.snp.makeConstraints { make in
            make.height.equalTo(Layout.buttonHeight)
        }

        let nameTap = UITapGestureRecognizer(target: self, action: #selector(handleNameTap))
        nameLabel.addGestureRecognizer(nameTap)
        followButton.addTarget(self, action: #selector(handleFollowTap), for: .touchUpInside)
        messageButton.addTarget(self, action: #selector(handleMessageTap), for: .touchUpInside)
    }

    @objc private func handleNameTap() {
        guard let currentModel else { return }
        delegate?.profileCardCell(self, didTapNameWith: currentModel.id)
    }

    @objc private func handleFollowTap() {
        guard let currentModel else { return }
        delegate?.profileCardCell(self, didTapFollowWith: currentModel.id)
    }

    @objc private func handleMessageTap() {
        guard let currentModel else { return }
        delegate?.profileCardCell(self, didTapMessageWith: currentModel.id)
    }
}

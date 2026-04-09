import UIKit

final class StateView: UIView {
    enum Style {
        case empty
        case error
    }

    private let messageLabel = UILabel()
    private let actionButton = UIButton(type: .system)
    private var onTap: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    func configure(style: Style, message: String, actionTitle: String, onTap: @escaping () -> Void) {
        switch style {
        case .empty:
            messageLabel.text = message
        case .error:
            messageLabel.text = message
        }
        actionButton.setTitle(actionTitle, for: .normal)
        self.onTap = onTap
        isHidden = false
    }

    private func setupUI() {
        messageLabel.textAlignment = .center
        messageLabel.textColor = .secondaryLabel
        messageLabel.numberOfLines = 0

        actionButton.setTitleColor(.white, for: .normal)
        actionButton.backgroundColor = .systemBlue
        actionButton.layer.cornerRadius = 8
        actionButton.contentEdgeInsets = UIEdgeInsets(top: 8, left: 20, bottom: 8, right: 20)
        actionButton.addTarget(self, action: #selector(handleTap), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [messageLabel, actionButton])
        stack.axis = .vertical
        stack.spacing = 12
        stack.alignment = .center

        addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -24)
        ])
    }

    @objc private func handleTap() {
        onTap?()
    }
}

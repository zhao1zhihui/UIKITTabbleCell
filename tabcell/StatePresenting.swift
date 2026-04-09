import UIKit

enum ListState {
    case content
    case empty(message: String)
    case error(isEmpty: Bool, error: APIError)
}

protocol StatePresenting: AnyObject {
    var stateView: StateView { get }
    func showErrorAlert(message: String)
    func showErrorView(message: String, retry: @escaping () -> Void)
    func showEmptyView(message: String, retry: @escaping () -> Void)
    func hideStateView()
    func updateStateView(_ state: ListState, retry: @escaping () -> Void)
}

extension StatePresenting where Self: UIViewController {
    func showErrorAlert(message: String) {
        let alert = UIAlertController(title: "提示", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "好的", style: .default))
        present(alert, animated: true)
    }

    func showErrorView(message: String, retry: @escaping () -> Void) {
        stateView.configure(style: .error, message: message, actionTitle: "重新加载", onTap: retry)
    }

    func showEmptyView(message: String, retry: @escaping () -> Void) {
        stateView.configure(style: .empty, message: message, actionTitle: "重新加载", onTap: retry)
    }

    func hideStateView() {
        stateView.isHidden = true
    }

    func updateStateView(_ state: ListState, retry: @escaping () -> Void) {
        switch state {
        case .content:
            hideStateView()
        case .empty(let message):
            showEmptyView(message: message, retry: retry)
        case .error(let isEmpty, let error):
            if isEmpty {
                showErrorView(message: "加载失败，点击重试", retry: retry)
            } else {
                guard case .cancelled = error  else {
                    showErrorAlert(message: error.message)
                    return
                }
                debugPrint(error.message)
            }
        }
    }
}

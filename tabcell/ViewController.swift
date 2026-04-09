//
//  ViewController.swift
//  tabcell
//
//  Created by wb-zhaozhihui on 2026/4/2.
//

import UIKit
import KafkaRefresh

final class ViewController: UIViewController, StatePresenting {
    private enum ProviderMode: Int, CaseIterable {
        case enumMapping
        case registry

        var title: String {
            switch self {
            case .enumMapping:
                return "Enum"
            case .registry:
                return "Registry"
            }
        }
    }

    private let tableView = UITableView(frame: .zero, style: .plain)
    private lazy var providerSwitchControl: UISegmentedControl = {
        let control = UISegmentedControl(items: ProviderMode.allCases.map(\.title))
        control.selectedSegmentIndex = ProviderMode.enumMapping.rawValue
        control.addTarget(self, action: #selector(handleProviderModeChanged(_:)), for: .valueChanged)
        return control
    }()
    private lazy var textCallbacks: TextCellCallbacks = {
        var callbacks = TextCellCallbacks()
        callbacks.onTitleTap = { [weak self] id in
            self?.handleTextTitleTap(id: id)
        }
        callbacks.onSubtitleTap = { [weak self] id in
            self?.handleTextSubtitleTap(id: id)
        }
        return callbacks
    }()
    private lazy var imageEventHandler: ImageCellEventHandler = {
        var handler = ImageCellEventHandler()
        handler.onEvent = { [weak self] id, event in
            self?.handleImageEvent(id: id, event: event)
        }
        return handler
    }()
    private var providerMode: ProviderMode = .enumMapping
    private var viewModel: TableViewModel!
    private var items: [AnyTableItem] = []
    private var refreshController: TableRefreshControlling?
    let stateView = StateView()

    override func viewDidLoad() {
        super.viewDidLoad()
        viewModel = makeViewModel(for: providerMode)
        title = "Dynamic Table"
        view.backgroundColor = .systemBackground

        setupProviderSwitch()
        setupTableView()
        setupConstraints()
        setupStateView()
        setupRefresh()
        Task { await refresh() }
    }

    private func setupProviderSwitch() {
        view.addSubview(providerSwitchControl)
    }

    private func setupTableView() {
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 72
        view.addSubview(tableView)
    }

    private func setupStateView() {
        stateView.isHidden = true
        view.addSubview(stateView)

        stateView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stateView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stateView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stateView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            stateView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24)
        ])
    }

    private func setupRefresh() {
        refreshController = TableRefreshController(
            tableView: tableView,
            onRefresh: { [weak self] in
                await self?.refresh()
            },
            onLoadMore: { [weak self] in
                await self?.loadMore()
            },
            hasMore: { [weak self] in
                self?.viewModel.paging.hasMore ?? false
            }
        )
        refreshController?.bind()
    }

    private func setupConstraints() {
        providerSwitchControl.translatesAutoresizingMaskIntoConstraints = false
        tableView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            providerSwitchControl.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            providerSwitchControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            providerSwitchControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            tableView.topAnchor.constraint(equalTo: providerSwitchControl.bottomAnchor, constant: 12),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func makeViewModel(for mode: ProviderMode) -> TableViewModel {
        switch mode {
        case .enumMapping:
            return TableViewModel(
                provider: EnumTableItemProvider(
                    textCallbacks: textCallbacks,
                    imageEventHandler: imageEventHandler,
                    actionDelegate: self,
                    profileDelegate: self
                )
            )
        case .registry:
            return TableViewModel(
                provider: RegistryTableItemProvider(
                    textCallbacks: textCallbacks,
                    imageEventHandler: imageEventHandler,
                    actionDelegate: self,
                    profileDelegate: self
                )
            )
        }
    }

    @objc private func handleProviderModeChanged(_ sender: UISegmentedControl) {
        guard let mode = ProviderMode(rawValue: sender.selectedSegmentIndex),
              mode != providerMode else { return }
        Task { [weak self] in
            await self?.switchProviderMode(to: mode)
        }
    }

    @MainActor
    private func switchProviderMode(to mode: ProviderMode) async {
        providerMode = mode
        viewModel = makeViewModel(for: mode)
        items = []
        tableView.reloadData()
        updateFooterVisibility()
        hideStateView()
        await refresh()
    }

    @MainActor
    private func refresh() async {
        let requestedMode = providerMode
        let result = await viewModel.refresh()
        guard !Task.isCancelled, requestedMode == providerMode else { return }
        switch result {
        case .success(let newItems):
            items = newItems
            registerCells()
            tableView.reloadData()
            updateFooterVisibility()
            let state: ListState = items.isEmpty ? .empty(message: "暂无数据") : .content
            updateStateView(state) { [weak self] in
                Task { [weak self] in
                    await self?.refresh()
                }
            }
        case .failure(let error):
            updateFooterVisibility()
            updateStateView(.error(isEmpty: items.isEmpty, error: error)) { [weak self] in
                Task { [weak self] in
                    await self?.refresh()
                }
            }
        }
    }

    @MainActor
    private func loadMore() async {
        guard viewModel.paging.hasMore else {
            return
        }
        let requestedMode = providerMode
        let result = await viewModel.loadMore()
        guard !Task.isCancelled, requestedMode == providerMode else { return }
        switch result {
        case .success(let newItems):
            items = newItems
            registerCells()
            tableView.reloadData()
            updateFooterVisibility()
        case .failure(let error):
            updateStateView(.error(isEmpty: items.isEmpty, error: error)) { [weak self] in
                Task { [weak self] in
                    await self?.refresh()
                }
            }
        }
    }

    private func updateFooterVisibility() {
        tableView.footRefreshControl?.isHidden = items.isEmpty
    }

    private func registerCells() {
        var seen: Set<ObjectIdentifier> = []
        for item in items {
            let identifier = ObjectIdentifier(item.cellClass)
            if seen.insert(identifier).inserted {
                tableView.register(item.cellClass, forCellReuseIdentifier: item.reuseID)
            }
        }
    }

    private func handleTextTitleTap(id: Int) {
        showEventAlert(message: "单独闭包: 点击了 Text title, id = \(id)")
    }

    private func handleTextSubtitleTap(id: Int) {
        showEventAlert(message: "单独闭包: 点击了 Text subtitle, id = \(id)")
    }

    private func handleImageEvent(id: Int, event: ImageRowEvent) {
        switch event {
        case .tapTitle:
            showEventAlert(message: "enum 事件: 点击了 Image title, id = \(id)")
        case .tapImage:
            showEventAlert(message: "enum 事件: 点击了 Image image, id = \(id)")
        case .tapURL:
            showEventAlert(message: "enum 事件: 点击了 Image url, id = \(id)")
        }
    }

    private func showEventAlert(message: String) {
        let alert = UIAlertController(title: "事件触发", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "知道了", style: .default))
        present(alert, animated: true)
    }
}

extension ViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let item = items[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: item.reuseID, for: indexPath)
        item.configure(cell)
        return cell
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let item = items[indexPath.row]
        return item.heightProvider?(tableView.bounds.width) ?? UITableView.automaticDimension
    }
}

extension ViewController: ActionCardCellDelegate {
    func actionCardCell(_ cell: ActionCardCell, didTapTitleWith id: Int) {
        showEventAlert(message: "delegate: 点击了 Action title, id = \(id)")
    }

    func actionCardCell(_ cell: ActionCardCell, didTapButtonWith id: Int) {
        showEventAlert(message: "delegate: 点击了 Action button, id = \(id)")
    }
}

extension ViewController: ProfileCardCellDelegate {
    func profileCardCell(_ cell: ProfileCardCell, didTapNameWith id: Int) {
        showEventAlert(message: "delegate: 点击了 Profile name, id = \(id)")
    }

    func profileCardCell(_ cell: ProfileCardCell, didTapFollowWith id: Int) {
        showEventAlert(message: "delegate: 点击了 Profile follow, id = \(id)")
    }

    func profileCardCell(_ cell: ProfileCardCell, didTapMessageWith id: Int) {
        showEventAlert(message: "delegate: 点击了 Profile message, id = \(id)")
    }
}

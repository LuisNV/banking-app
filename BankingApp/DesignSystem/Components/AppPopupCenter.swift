import Observation
import SwiftUI
import UIKit

/// Hiện popup và toast trong một cửa sổ riêng nằm trên cùng, nên không bị thanh tab,
/// sheet hay màn toàn màn hình che. Popup đến cùng lúc thì xếp hàng hiện lần lượt.
@MainActor
@Observable
final class AppPopupCenter {
    static let shared = AppPopupCenter()

    private(set) var popup: AppPopup?
    private(set) var toast: AppToast?
    /// Khung toast trên màn hình (cửa sổ chỉ nhận chạm trong khung này khi không có popup).
    @ObservationIgnored fileprivate var toastFrame: CGRect = .zero

    private var queue: [AppPopup] = []
    private var window: PassthroughWindow?
    private var toastTask: Task<Void, Never>?

    // MARK: Popup

    func present(_ popup: AppPopup) {
        if self.popup == nil {
            self.popup = popup
            announce(popup.title)
        } else {
            queue.append(popup)
        }
        updateWindow()
    }

    /// Đóng popup theo `id` (đang hiện hoặc đang chờ).
    func dismiss(id: UUID) {
        queue.removeAll { $0.id == id }
        guard popup?.id == id else { return }
        popup = nil
        if !queue.isEmpty {
            // Chờ popup cũ biến mất rồi mới hiện popup kế tiếp.
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(250))
                guard self.popup == nil, !self.queue.isEmpty else { return }
                let next = self.queue.removeFirst()
                self.popup = next
                self.announce(next.title)
            }
        }
        updateWindow()
    }

    fileprivate func perform(_ action: AppPopup.Action, of popup: AppPopup) {
        dismiss(id: popup.id)
        action.handler()
    }

    // MARK: Toast

    func showToast(_ toast: AppToast) {
        self.toast = toast
        announce(toast.title)
        updateWindow()
        toastTask?.cancel()
        let id = toast.id
        toastTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(toast.duration))
            guard !Task.isCancelled else { return }
            self.hideToast(id: id)
        }
    }

    func hideToast(id: UUID? = nil) {
        guard let toast, id == nil || toast.id == id else { return }
        self.toast = nil
        toastFrame = .zero
        updateWindow()
    }

    // MARK: Cửa sổ

    private func updateWindow() {
        let needsWindow = popup != nil || toast != nil || !queue.isEmpty
        if needsWindow {
            if window == nil { window = makeWindow() }
            window?.isHidden = false
        } else {
            // Đợi hiệu ứng ẩn chạy xong rồi mới giấu cửa sổ.
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(300))
                if self.popup == nil, self.toast == nil, self.queue.isEmpty {
                    self.window?.isHidden = true
                }
            }
        }
    }

    private func makeWindow() -> PassthroughWindow? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        guard let scene = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first else {
            return nil
        }
        let window = PassthroughWindow(windowScene: scene)
        window.center = self
        window.windowLevel = .alert + 1
        window.backgroundColor = .clear
        let host = UIHostingController(rootView: AppPopupHost(center: self))
        host.view.backgroundColor = .clear
        window.rootViewController = host
        return window
    }

    private func announce(_ text: String) {
        UIAccessibility.post(notification: .announcement, argument: text)
    }
}

/// Cửa sổ nhận chạm khi có popup; khi chỉ có toast thì chỉ nhận chạm trong khung toast.
private final class PassthroughWindow: UIWindow {
    weak var center: AppPopupCenter?

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let center else { return nil }
        let hasPopup = MainActor.assumeIsolated { center.popup != nil }
        if hasPopup { return super.hitTest(point, with: event) }
        let toastFrame = MainActor.assumeIsolated { center.toastFrame }
        return toastFrame.contains(point) ? super.hitTest(point, with: event) : nil
    }
}

/// Nội dung cửa sổ: lớp nền tối + popup ở giữa, toast ở trên.
private struct AppPopupHost: View {
    let center: AppPopupCenter

    var body: some View {
        ZStack {
            if let popup = center.popup {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .accessibilityHidden(true)

                AppPopupCard(popup: popup) { action in
                    center.perform(action, of: popup)
                }
                .padding(.horizontal, 28)
                .transition(.scale(scale: 0.92).combined(with: .opacity))
                .id(popup.id)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .top) {
            if let toast = center.toast {
                AppToastView(
                    toast: toast,
                    onAction: {
                        center.hideToast(id: toast.id)
                        toast.action?()
                    },
                    onClose: { center.hideToast(id: toast.id) }
                )
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .background(
                    GeometryReader { proxy in
                        Color.clear
                            .onAppear { center.toastFrame = proxy.frame(in: .global) }
                            .onChange(of: proxy.frame(in: .global)) { _, frame in center.toastFrame = frame }
                    }
                )
                .gesture(
                    DragGesture(minimumDistance: 10).onEnded { value in
                        if value.translation.height < -20 { center.hideToast(id: toast.id) }
                    }
                )
                .transition(.move(edge: .top).combined(with: .opacity))
                .id(toast.id)
            }
        }
        .animation(.spring(duration: 0.3), value: center.popup?.id)
        .animation(.spring(duration: 0.35), value: center.toast?.id)
    }
}

// MARK: - Dùng trong view

extension View {
    /// Hiện popup khi `isPresented` thành `true`. Bấm nút nào thì popup đóng và `isPresented` về `false`.
    func appPopup(isPresented: Binding<Bool>, popup: @escaping () -> AppPopup) -> some View {
        modifier(AppPopupModifier(isPresented: isPresented, makePopup: popup))
    }

    /// Thay cho `.alert(title, isPresented:, presenting: message)` khi báo lỗi.
    /// Lỗi mạng tự dùng kiểu "Mất kết nối" (có "Thử lại" nếu truyền `retry`).
    func errorPopup(
        _ title: String,
        isPresented: Binding<Bool>,
        message: String?,
        retry: (() -> Void)? = nil
    ) -> some View {
        appPopup(isPresented: isPresented) {
            .error(title: title, message: message ?? "Đã có lỗi xảy ra. Vui lòng thử lại.", retry: retry)
        }
    }
}

private struct AppPopupModifier: ViewModifier {
    @Binding var isPresented: Bool
    let makePopup: () -> AppPopup
    @State private var presentedID: UUID?

    func body(content: Content) -> some View {
        content
            .onChange(of: isPresented, initial: true) { _, shown in
                let center = AppPopupCenter.shared
                if shown {
                    guard presentedID == nil else { return }
                    var popup = makePopup()
                    // Bấm nút nào cũng đưa isPresented về false (giống .alert).
                    let binding = $isPresented
                    popup.primary.handler = { [handler = popup.primary.handler] in
                        binding.wrappedValue = false
                        handler()
                    }
                    if let secondary = popup.secondary {
                        popup.secondary?.handler = { [handler = secondary.handler] in
                            binding.wrappedValue = false
                            handler()
                        }
                    }
                    presentedID = popup.id
                    center.present(popup)
                } else if let id = presentedID {
                    presentedID = nil
                    center.dismiss(id: id)
                }
            }
            .onDisappear {
                if let id = presentedID {
                    presentedID = nil
                    AppPopupCenter.shared.dismiss(id: id)
                }
            }
    }
}

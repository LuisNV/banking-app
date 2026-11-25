import SwiftUI
import UIKit

/// Màn chỉnh ảnh đại diện: kéo, phóng to (chụm hai ngón hoặc chạm hai lần) để ảnh vừa khung tròn.
struct AvatarCropView: View {
    let image: UIImage
    let onCancel: () -> Void
    let onCropped: (UIImage) -> Void

    @State private var zoom: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var committedZoom: CGFloat = 1
    @State private var committedOffset: CGSize = .zero
    @State private var isProcessing = false

    private static let hintHeight: CGFloat = 52
    private static let barHeight: CGFloat = 64

    var body: some View {
        GeometryReader { proxy in
            // Tự tính khoảng tai thỏ / thanh home: trong màn toàn màn hình (fullScreenCover)
            // vùng an toàn tự động có lúc bằng 0, làm chữ hướng dẫn đè lên thanh trạng thái.
            let insets = Self.screenInsets(proxy.safeAreaInsets)
            let width = proxy.size.width
            let cropHeight = max(160, proxy.size.height - insets.top - insets.bottom - Self.hintHeight - Self.barHeight)
            let diameter = max(120, min(width - 40, cropHeight - 32))
            let geometry = AvatarCropGeometry(imageSize: image.size, cropDiameter: diameter)

            VStack(spacing: 0) {
                Color.clear.frame(height: insets.top)

                Text("Kéo và phóng to để ảnh vừa khung")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(width: width, height: Self.hintHeight)

                cropArea(geometry: geometry, size: CGSize(width: width, height: cropHeight))

                bottomBar(geometry: geometry)
                    .frame(width: width, height: Self.barHeight)

                Color.clear.frame(height: insets.bottom)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
        }
        .ignoresSafeArea()
        .background(Color.black.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Chỉnh ảnh đại diện")
    }

    /// Vùng chỉnh ảnh: khung cố định, phần ảnh thừa bị cắt; ngoài khung tròn bị làm tối.
    private func cropArea(geometry: AvatarCropGeometry, size: CGSize) -> some View {
        let shown = geometry.displayedSize(zoom: zoom)
        return Color.black
            .frame(width: size.width, height: size.height)
            .overlay {
                Image(uiImage: image)
                    .resizable()
                    .frame(width: shown.width, height: shown.height)
                    .offset(offset)
                    .accessibilityHidden(true)
            }
            .clipped()
            .overlay {
                CropMask(diameter: geometry.cropDiameter)
                    .frame(width: size.width, height: size.height)
                    .allowsHitTesting(false)
            }
            .contentShape(Rectangle())
            .gesture(
                SimultaneousGesture(
                    MagnifyGesture()
                        .onChanged { value in
                            zoom = geometry.clampedZoom(committedZoom * value.magnification)
                            offset = geometry.clampedOffset(offset, zoom: zoom)
                        }
                        .onEnded { _ in commit() },
                    DragGesture()
                        .onChanged { value in
                            offset = geometry.clampedOffset(
                                CGSize(
                                    width: committedOffset.width + value.translation.width,
                                    height: committedOffset.height + value.translation.height
                                ),
                                zoom: zoom
                            )
                        }
                        .onEnded { _ in commit() }
                )
            )
            .onTapGesture(count: 2) {
                withAnimation(.spring(duration: 0.3)) {
                    zoom = zoom > 1.01 ? 1 : 2
                    offset = geometry.clampedOffset(offset, zoom: zoom)
                }
                commit()
            }
    }

    /// Khoảng an toàn thật của màn hình: lấy giá trị lớn hơn giữa SwiftUI và cửa sổ hiện tại.
    private static func screenInsets(_ fromProxy: EdgeInsets) -> EdgeInsets {
        let window = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)
        let windowInsets = window?.safeAreaInsets ?? .zero
        return EdgeInsets(
            top: max(fromProxy.top, windowInsets.top),
            leading: 0,
            bottom: max(fromProxy.bottom, windowInsets.bottom),
            trailing: 0
        )
    }

    private func bottomBar(geometry: AvatarCropGeometry) -> some View {
        HStack {
            Button("Huỷ", action: onCancel)
                .font(.body)
                .foregroundStyle(.white)
                .frame(minWidth: 64, minHeight: 44)
                .disabled(isProcessing)

            Spacer()

            Button {
                withAnimation(.spring(duration: 0.3)) {
                    zoom = 1
                    offset = .zero
                }
                commit()
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Đặt lại")
            .disabled(isProcessing)

            Spacer()

            Button {
                choose(geometry: geometry)
            } label: {
                if isProcessing {
                    ProgressView().tint(.black)
                        .frame(minWidth: 64, minHeight: 36)
                } else {
                    Text("Chọn")
                        .font(.body.weight(.semibold))
                        .frame(minWidth: 64, minHeight: 36)
                }
            }
            .foregroundStyle(.black)
            .padding(.horizontal, 8)
            .background(Capsule().fill(.white))
            .frame(minHeight: 44)
            .disabled(isProcessing)
        }
        .padding(.horizontal, 20)
    }

    private func commit() {
        committedZoom = zoom
        committedOffset = offset
    }

    private func choose(geometry: AvatarCropGeometry) {
        isProcessing = true
        let rect = geometry.cropRect(zoom: zoom, offset: offset)
        let source = image
        Task {
            let cropped = await Task.detached(priority: .userInitiated) {
                AvatarImageCropper.crop(source, to: rect)
            }.value
            isProcessing = false
            onCropped(cropped ?? source)
        }
    }
}

/// Lớp tối phủ ngoài khung tròn + viền khung.
private struct CropMask: View {
    let diameter: CGFloat

    var body: some View {
        ZStack {
            // Phủ tối toàn màn rồi "đục" lỗ tròn ở giữa.
            Rectangle()
                .fill(Color.black.opacity(0.6))
                .overlay {
                    Circle()
                        .frame(width: diameter, height: diameter)
                        .blendMode(.destinationOut)
                }
                .compositingGroup()

            Circle()
                .stroke(.white.opacity(0.9), lineWidth: 1.5)
                .frame(width: diameter, height: diameter)
        }
    }
}

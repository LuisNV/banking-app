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

    var body: some View {
        GeometryReader { proxy in
            let diameter = max(120, min(proxy.size.width - 40, proxy.size.height - 220))
            let geometry = AvatarCropGeometry(imageSize: image.size, cropDiameter: diameter)
            let shown = geometry.displayedSize(zoom: zoom)

            // Lớp ảnh: khung cố định bằng màn hình. Ảnh phóng to có thể rộng hơn màn hình,
            // nên phải cố định khung + cắt phần thừa, nếu không bố cục bị kéo rộng theo ảnh
            // và các nút bị đẩy ra ngoài mép.
            Color.black
                .frame(width: proxy.size.width, height: proxy.size.height)
                .overlay {
                    Image(uiImage: image)
                        .resizable()
                        .frame(width: shown.width, height: shown.height)
                        .offset(offset)
                        .accessibilityHidden(true)
                }
                .clipped()
                .overlay {
                    CropMask(diameter: diameter)
                        .frame(width: proxy.size.width, height: proxy.size.height)
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
                .overlay(alignment: .top) {
                    Text("Kéo và phóng to để ảnh vừa khung")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(.top, 20)
                        .allowsHitTesting(false)
                }
                .overlay(alignment: .bottom) {
                    bottomBar(geometry: geometry)
                        .frame(width: proxy.size.width)
                }
        }
        .background(Color.black.ignoresSafeArea())
        // Không ẩn thanh trạng thái: khi ẩn, vùng an toàn phía trên bị thu lại và chữ hướng dẫn
        // đè lên tai thỏ / Dynamic Island. Giao diện tối để giờ, pin hiện chữ trắng trên nền đen.
        .preferredColorScheme(.dark)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Chỉnh ảnh đại diện")
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
        .padding(.bottom, 12)
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

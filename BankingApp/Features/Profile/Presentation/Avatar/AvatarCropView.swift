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

            ZStack {
                Image(uiImage: image)
                    .resizable()
                    .frame(width: shown.width, height: shown.height)
                    .offset(offset)
                    .accessibilityHidden(true)

                CropMask(diameter: diameter)
                    .allowsHitTesting(false)

                VStack {
                    Text("Kéo và phóng to để ảnh vừa khung")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(.top, 20)
                    Spacer()
                    bottomBar(geometry: geometry)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            // Cắt phần ảnh tràn ra vùng tai thỏ / thanh home cho khớp lớp phủ.
            .clipped()
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
        .background(Color.black.ignoresSafeArea())
        .statusBarHidden()
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
        GeometryReader { proxy in
            let rect = CGRect(
                x: (proxy.size.width - diameter) / 2,
                y: (proxy.size.height - diameter) / 2,
                width: diameter,
                height: diameter
            )
            ZStack {
                Path { path in
                    path.addRect(CGRect(origin: .zero, size: proxy.size))
                    path.addEllipse(in: rect)
                }
                .fill(Color.black.opacity(0.6), style: FillStyle(eoFill: true))

                Circle()
                    .stroke(.white.opacity(0.9), lineWidth: 1.5)
                    .frame(width: diameter, height: diameter)
                    .position(x: rect.midX, y: rect.midY)
            }
        }
    }
}

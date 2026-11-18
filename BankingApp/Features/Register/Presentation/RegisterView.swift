import SwiftUI

/// Luồng đăng ký 4 bước: Thông tin → Mật khẩu → Xác minh email → Hoàn tất.
struct RegisterView: View {
    @State private var viewModel: RegisterViewModel

    init(viewModel: RegisterViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        VStack(spacing: 0) {
            if let number = viewModel.step.number {
                RegisterTopBar(
                    stepNumber: number,
                    stepCount: RegisterViewModel.Step.numberedCount,
                    onBack: viewModel.goBack
                )
            }

            ZStack {
                switch viewModel.step {
                case .info:
                    RegisterInfoStep(viewModel: viewModel).transition(stepTransition)
                case .password:
                    RegisterPasswordStep(viewModel: viewModel).transition(stepTransition)
                case .verify:
                    RegisterVerifyStep(viewModel: viewModel).transition(stepTransition)
                case .done:
                    RegisterDoneStep(viewModel: viewModel).transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(AppColor.background)
        .animation(.snappy(duration: 0.35), value: viewModel.step)
        .alert(
            "Không thể tiếp tục",
            isPresented: $viewModel.isShowingError,
            presenting: viewModel.errorMessage
        ) { _ in
            Button("Đóng", role: .cancel) {}
        } message: { message in
            Text(message)
        }
    }

    private var stepTransition: AnyTransition {
        .push(from: viewModel.isNavigatingBack ? .leading : .trailing)
    }
}

#Preview {
    RegisterView(viewModel: RegisterViewModel(onCancel: {}, onFinished: { _ in }))
}

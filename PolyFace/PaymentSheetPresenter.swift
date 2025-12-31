import SwiftUI
import StripePaymentSheet
#if canImport(UIKit)
import UIKit
#endif

private struct PaymentSheetPresenter: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    @Binding var paymentSheet: PaymentSheet?
    let onCompletion: (PaymentSheetResult) -> Void

    func makeUIViewController(context: Context) -> UIViewController {
        let controller = UIViewController()
        controller.view.backgroundColor = .clear
        return controller
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        guard isPresented, let sheet = paymentSheet, context.coordinator.isPresenting == false else { return }
        context.coordinator.isPresenting = true

        sheet.present(from: uiViewController) { result in
            onCompletion(result)
            // Reset presentation state
            DispatchQueue.main.async {
                self.isPresented = false
                self.paymentSheet = nil
                context.coordinator.isPresenting = false
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        var isPresenting = false
    }
}

extension View {
    func paymentSheet(
        isPresented: Binding<Bool>,
        paymentSheet: Binding<PaymentSheet?>,
        onCompletion: @escaping (PaymentSheetResult) -> Void
    ) -> some View {
        background(
            PaymentSheetPresenter(
                isPresented: isPresented,
                paymentSheet: paymentSheet,
                onCompletion: onCompletion
            )
        )
    }
}

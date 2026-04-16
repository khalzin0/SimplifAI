import SwiftUI
import QuickLook
import UIKit

struct HeaderGlassModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        } else {
            content
        }
    }
}

struct ImportButtonGlassModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        } else {
            content
        }
    }
}

struct FloatingDoneButtonModifier: ViewModifier {
    let primaryAccent: Color
    let secondaryAccent: Color
    let isDarkModeActive: Bool

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .background(
                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    primaryAccent.opacity(0.88),
                                    secondaryAccent.opacity(0.94)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
                .glassEffect(.regular.tint(primaryAccent).interactive(), in: Capsule(style: .continuous))
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                )
        } else {
            content
                .background(
                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    primaryAccent.opacity(isDarkModeActive ? 0.80 : 0.22),
                                    secondaryAccent.opacity(isDarkModeActive ? 0.92 : 0.28)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
        }
    }
}

struct CameraPicker: UIViewControllerRepresentable {
    let onImagePicked: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator {
        Coordinator(onImagePicked: onImagePicked, dismiss: dismiss)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        private let onImagePicked: (UIImage) -> Void
        private let dismiss: DismissAction

        init(onImagePicked: @escaping (UIImage) -> Void, dismiss: DismissAction) {
            self.onImagePicked = onImagePicked
            self.dismiss = dismiss
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            dismiss()
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                onImagePicked(image)
            }
            dismiss()
        }
    }
}

struct ImportedFileQuickLookPreview: UIViewControllerRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator {
        Coordinator(url: url)
    }

    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: QLPreviewController, context: Context) {
        context.coordinator.url = url
        uiViewController.reloadData()
    }

    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        var url: URL

        init(url: URL) {
            self.url = url
        }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
            1
        }

        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            url as NSURL
        }
    }
}

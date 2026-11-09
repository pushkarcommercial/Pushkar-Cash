import UIKit

enum FlexConfirmPresentation {
    case alert
    case illustrated
    case card
}

enum FlexConfirmSheet {
    static func present(on host: UIViewController, title: String, message: String,
                        confirmTitle: String = FlexPhraseBook.Dialog.confirm,
                        cancelTitle: String = FlexPhraseBook.Dialog.cancel,
                        destructive: Bool = false,
                        art: String? = nil,
                        presentation: FlexConfirmPresentation? = nil,
                        onConfirm: @escaping () -> Void) {
        let style = presentation ?? (art != nil ? .illustrated : .alert)
        if let art {
            switch style {
            case .card:
                FlexCardConfirmSheet.present(on: host, art: art, title: title, message: message,
                                             confirmTitle: confirmTitle, cancelTitle: cancelTitle,
                                             onConfirm: onConfirm)
            case .illustrated:
                FlexIllustratedSheet.present(on: host, art: art, title: title, message: message,
                                             confirmTitle: confirmTitle, cancelTitle: cancelTitle,
                                             onConfirm: onConfirm)
            case .alert:
                break
            }
            if style != .alert { return }
        }
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: cancelTitle, style: .cancel))
        alert.addAction(UIAlertAction(title: confirmTitle, style: destructive ? .destructive : .default) { _ in
            onConfirm()
        })
        host.present(alert, animated: true)
    }
}

import UIKit
import SnapKit

enum FlexFieldHintKind {
    case amountReceived
    case serviceFee
    case interest
}

enum FlexFieldHintScene {
    case product
    case orderDetail
    case success
}

enum FlexFieldHintBubble {
    private static weak var activeBackdrop: UIView?

    static func present(on host: UIView, kind: FlexFieldHintKind, scene: FlexFieldHintScene) {
        dismiss()
        let message = FlexPhraseBook.FieldHint.message(for: kind, scene: scene)

        let backdrop = UIView(frame: host.bounds)
        backdrop.backgroundColor = UIColor.black.withAlphaComponent(0.35)
        backdrop.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        let bubble = UIView()
        bubble.backgroundColor = .white
        bubble.layer.cornerRadius = 12
        bubble.layer.shadowColor = UIColor.black.cgColor
        bubble.layer.shadowOpacity = 0.12
        bubble.layer.shadowOffset = CGSize(width: 0, height: 4)
        bubble.layer.shadowRadius = 12

        let label = UILabel()
        label.text = message
        label.font = FlexTypography.regular(14)
        label.textColor = FlexPalette.inkPrimary
        label.numberOfLines = 0
        label.textAlignment = .center

        bubble.addSubview(label)
        backdrop.addSubview(bubble)
        host.addSubview(backdrop)

        label.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(16)
        }
        bubble.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.leading.greaterThanOrEqualToSuperview().offset(32)
            make.trailing.lessThanOrEqualToSuperview().offset(-32)
        }

        let dismissTap = UITapGestureRecognizer(target: FlexFieldHintDismissProxy.shared,
                                                  action: #selector(FlexFieldHintDismissProxy.dismissActive))
        backdrop.addGestureRecognizer(dismissTap)

        activeBackdrop = backdrop
    }

    static func dismiss() {
        activeBackdrop?.removeFromSuperview()
        activeBackdrop = nil
    }

    static func wireHint(on view: UIView, kind: FlexFieldHintKind, onTap: @escaping () -> Void) {
        view.isUserInteractionEnabled = true
        let tap = UITapGestureRecognizer(target: FlexLedgerTapProxy.shared, action: #selector(FlexLedgerTapProxy.invoke))
        view.addGestureRecognizer(tap)
        FlexLedgerTapProxy.shared.store(onTap, for: view)
    }
}

private final class FlexFieldHintDismissProxy: NSObject {
    static let shared = FlexFieldHintDismissProxy()

    @objc func dismissActive() {
        FlexFieldHintBubble.dismiss()
    }
}

extension UIViewController {
    func presentFieldHint(_ kind: FlexFieldHintKind, scene: FlexFieldHintScene) {
        FlexToast.show(FlexPhraseBook.FieldHint.message(for: kind, scene: scene), on: view)
    }
}

import UIKit
import SnapKit

/// 4102007 / timeout failure — Flex empty layout (banner + art).
final class FlexRecommendEmptyCanvas: FlexBaseCanvas {

    init() {
        super.init(nibName: nil, bundle: nil)
        hidesBottomBarWhenPushed = true
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = FlexPalette.canvasGray
        embedNavStripIfNeeded(showBack: true, title: FlexPhraseBook.Hub.noRecommendTitle)

        let banner = FlexCofferWidgets.makeHintBanner(FlexPhraseBook.Hub.noRecommendCopy)

        let artWrap = UIView()
        artWrap.backgroundColor = UIColor.white.withAlphaComponent(0.72)
        artWrap.layer.cornerRadius = 90
        let art = UIImageView(image: FlexSlice.slice(FlexSliceCatalog.recommendRejectMist))
        art.contentMode = .scaleAspectFit
        artWrap.addSubview(art)
        art.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(120)
        }

        view.addSubview(banner)
        view.addSubview(artWrap)
        banner.snp.makeConstraints { make in
            make.top.equalTo(contentTopAnchor()).offset(12)
            make.leading.trailing.equalToSuperview().inset(16)
        }
        artWrap.snp.makeConstraints { make in
            make.top.equalTo(banner.snp.bottom).offset(36)
            make.centerX.equalToSuperview()
            make.width.height.equalTo(180)
        }
    }
}

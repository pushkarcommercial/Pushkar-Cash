import UIKit

enum FlexSlice {
    static func image(_ name: String) -> UIImage? {
        slice(name)
    }

    /// Loads themed art from `Assets.xcassets` (`rupeeArt_*` / curated stems).
    static func slice(_ stem: String) -> UIImage? {
        UIImage(named: stem)
    }
}

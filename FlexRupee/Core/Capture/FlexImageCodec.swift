import UIKit

enum FlexImageCodec {
    /// Generic upload budget (feedback etc.).
    static let maxKilobytes = 150
    /// Downscale target when a document is over the max budget.
    static let documentMaxSide: CGFloat = 1600
    /// Aadhaar / PAN: ≤600 KB keep as-is; over 600 KB compress down to ≤600 KB.
    static let documentMaxKilobytes = 600
    /// Soft pixel cap before encode (OOM guard only — does not force compress under budget).
    private static let prepareSoftMaxSide: CGFloat = 4096

    static func jpegBase64(from image: UIImage) -> String? {
        guard let data = jpegData(from: image, maxKilobytes: maxKilobytes) else { return nil }
        return data.base64EncodedString()
    }

    /// Face liveness: ≤600 KB keep; >600 KB compress to ≤600 KB (same cap as ID / tax).
    static func livenessBase64(from image: UIImage) -> String? {
        guard let data = jpegData(from: image, maxKilobytes: documentMaxKilobytes) else { return nil }
        return data.base64EncodedString()
    }

    /// Identity document JPEG after `prepareIdentityDocument` (or already prepared by coordinator).
    static func documentBase64(from image: UIImage) -> String? {
        guard let data = documentJpegData(from: image) else { return nil }
        return data.base64EncodedString()
    }

    /// JPEG bytes + decoded preview that matches the upload payload (same pixels / quality).
    /// Proportional scale + quality only — never crops the frame.
    static func documentPayload(from image: UIImage) -> (base64: String, preview: UIImage)? {
        guard let data = documentJpegData(from: image),
              let preview = UIImage(data: data) else { return nil }
        return (data.base64EncodedString(), preview)
    }

    /// Aadhaar / PAN: ≤600 KB → no compress; >600 KB → scale + quality until ≤600 KB.
    static func documentJpegData(from image: UIImage) -> Data? {
        jpegData(from: image, maxKilobytes: documentMaxKilobytes)
    }

    /// Normalize EXIF; soft max-side shrink is proportional (no crop).
    static func prepareIdentityDocument(_ image: UIImage) -> UIImage {
        limitMaxSide(image, maxSide: prepareSoftMaxSide)
    }

    /// Downscale then horizontal flip so front selfie matches mirrored preview without OOM.
    static func prepareFrontSelfie(_ image: UIImage) -> UIImage {
        let scaled = limitMaxSide(image, maxSide: 1280)
        return mirroredHorizontally(scaled)
    }

    /// Horizontal flip so front-camera review matches the mirrored preview.
    static func mirroredHorizontally(_ image: UIImage) -> UIImage {
        let size = image.size
        guard size.width > 0, size.height > 0 else { return image }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { context in
            context.cgContext.translateBy(x: size.width, y: 0)
            context.cgContext.scaleBy(x: -1, y: 1)
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    /// Encode JPEG. Hard cap: **never over** `maxKilobytes` (证件：≤600 不压，>600 压到 ≤600).
    /// Soft floor: prefer ≥ `minKilobytes` when compressing. Proportional scale — never crops.
    static func jpegData(from image: UIImage,
                         minKilobytes: Int = 0,
                         maxKilobytes: Int = maxKilobytes) -> Data? {
        let baked = bake(image)
        let floorBytes = max(0, minKilobytes) * 1024
        let cap = maxKilobytes * 1024

        guard let original = baked.jpegData(compressionQuality: 1.0) else { return nil }
        // Already under hard max — no further compression.
        if original.count <= cap {
            return original
        }

        // Over max — must get ≤ cap. Prefer candidates still ≥ floor when possible.
        let preferredQualities: [CGFloat] = [0.92, 0.88, 0.80, 0.72, 0.64, 0.55, 0.45, 0.35, 0.25]
        /// Best under cap and ≥ floor (largest in-band).
        var inBand: Data?
        /// Any under cap (largest under-cap that may be below floor).
        var underCap: Data?

        func consider(_ data: Data) {
            guard data.count <= cap else { return }
            if underCap == nil || data.count > (underCap?.count ?? 0) {
                underCap = data
            }
            if floorBytes == 0 || data.count >= floorBytes {
                if inBand == nil || data.count > (inBand?.count ?? 0) {
                    inBand = data
                }
            }
        }

        // Quality on full frame first, then proportional max-side steps (no crop).
        for quality in preferredQualities {
            guard let data = baked.jpegData(compressionQuality: quality) else { continue }
            consider(data)
            if let hit = inBand { return hit }
        }

        let maxEdgeSteps: [CGFloat] = [2560, 2200, 1920, 1600, 1440, 1280, 1080, 960, 800, 640]
        for maxEdge in maxEdgeSteps {
            let scaled = scaledToMaxSide(baked, maxSide: maxEdge)
            for quality in preferredQualities {
                guard let data = scaled.jpegData(compressionQuality: quality) else { continue }
                consider(data)
            }
            if let hit = inBand { return hit }
        }

        // Keep shrinking proportionally until under hard cap (cap wins over floor).
        var scaled = scaledToMaxSide(baked, maxSide: 640)
        var longest = max(scaled.size.width, scaled.size.height)
        var quality: CGFloat = 0.50
        while longest > 160 {
            longest *= 0.82
            let ratio = longest / max(scaled.size.width, scaled.size.height)
            let target = CGSize(width: max(1, scaled.size.width * ratio),
                                height: max(1, scaled.size.height * ratio))
            scaled = render(scaled, in: target)
            guard let data = scaled.jpegData(compressionQuality: quality) else { break }
            consider(data)
            if let hit = inBand { return hit }
            if underCap != nil, floorBytes == 0 { return underCap }
            quality = max(0.35, quality - 0.05)
        }

        // Hard rule: never return over max. Prefer ≥ floor when available.
        return inBand ?? underCap
    }

    /// Crop `image` to `rectInContainer` as shown under `.scaleAspectFill` in `containerSize`.
    /// Used to keep ID/PAN stills aligned with the on-screen shooting guide.
    static func cropAspectFill(_ image: UIImage,
                               containerSize: CGSize,
                               rectInContainer: CGRect) -> UIImage {
        let baked = bake(image)
        let imageSize = baked.size
        guard imageSize.width > 1, imageSize.height > 1,
              containerSize.width > 1, containerSize.height > 1 else { return baked }

        let fillScale = max(containerSize.width / imageSize.width,
                            containerSize.height / imageSize.height)
        let displayed = CGSize(width: imageSize.width * fillScale,
                               height: imageSize.height * fillScale)
        let offset = CGPoint(x: (containerSize.width - displayed.width) / 2,
                             y: (containerSize.height - displayed.height) / 2)

        var crop = CGRect(
            x: (rectInContainer.minX - offset.x) / fillScale,
            y: (rectInContainer.minY - offset.y) / fillScale,
            width: rectInContainer.width / fillScale,
            height: rectInContainer.height / fillScale
        ).integral
        crop = crop.intersection(CGRect(origin: .zero, size: imageSize))
        guard crop.width > 1, crop.height > 1 else { return baked }

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: crop.size, format: format)
        return renderer.image { _ in
            baked.draw(at: CGPoint(x: -crop.origin.x, y: -crop.origin.y))
        }
    }

    static func aspectFitRect(for imageSize: CGSize, in bounds: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0, bounds.width > 0, bounds.height > 0 else {
            return CGRect(origin: .zero, size: bounds)
        }
        let scale = min(bounds.width / imageSize.width, bounds.height / imageSize.height)
        let size = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return CGRect(x: (bounds.width - size.width) / 2,
                      y: (bounds.height - size.height) / 2,
                      width: size.width,
                      height: size.height)
    }

    static func rotate(_ image: UIImage, byDegrees degrees: CGFloat) -> UIImage {
        let radians = degrees * .pi / 180
        var bound = CGRect(origin: .zero, size: image.size).applying(CGAffineTransform(rotationAngle: radians))
        bound.origin = .zero
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: bound.size, format: format)
        return renderer.image { ctx in
            ctx.cgContext.translateBy(x: bound.width / 2, y: bound.height / 2)
            ctx.cgContext.rotate(by: radians)
            image.draw(in: CGRect(
                x: -image.size.width / 2,
                y: -image.size.height / 2,
                width: image.size.width,
                height: image.size.height
            ))
        }
    }

    static func limitMaxSide(_ image: UIImage, maxSide: CGFloat) -> UIImage {
        let baked = bake(image)
        return scaledToMaxSide(baked, maxSide: maxSide)
    }

    private static func scaledToMaxSide(_ baked: UIImage, maxSide: CGFloat) -> UIImage {
        let size = baked.size
        let longest = max(size.width, size.height)
        guard longest > maxSide else { return baked }
        let scale = maxSide / longest
        let target = CGSize(width: max(1, floor(size.width * scale)),
                            height: max(1, floor(size.height * scale)))
        return render(baked, in: target)
    }

    private static func bake(_ image: UIImage) -> UIImage {
        let sourceSize: CGSize
        if let cgImage = image.cgImage {
            let scale = max(image.scale, 1)
            sourceSize = CGSize(width: CGFloat(cgImage.width) / scale,
                                height: CGFloat(cgImage.height) / scale)
        } else {
            sourceSize = image.size
        }
        let size: CGSize
        switch image.imageOrientation {
        case .left, .leftMirrored, .right, .rightMirrored:
            size = CGSize(width: sourceSize.height, height: sourceSize.width)
        default:
            size = sourceSize
        }
        guard size.width > 0, size.height > 0 else { return image }
        return render(image, in: size)
    }

    private static func render(_ image: UIImage, in size: CGSize) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

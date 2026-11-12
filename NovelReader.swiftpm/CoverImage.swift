import UIKit

enum CoverImage {
    /// 选封面时允许的原图大小上限(与原网页版一致)。
    static let maxFileBytes = 5 * 1024 * 1024

    /// 把选中的图片缩小并转成 JPEG,避免书库文件被大图撑大。
    /// 最长边不超过 `maxDimension` 像素;不是图片时返回 nil。
    static func normalized(_ data: Data, maxDimension: CGFloat = 800) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let size = image.size
        guard size.width > 0, size.height > 0 else { return nil }

        let scale = min(1, maxDimension / max(size.width, size.height))
        let target = CGSize(
            width: max((size.width * scale).rounded(), 1),
            height: max((size.height * scale).rounded(), 1)
        )

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: target, format: format)
        let rendered = renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: target))
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        return rendered.jpegData(compressionQuality: 0.82)
    }
}

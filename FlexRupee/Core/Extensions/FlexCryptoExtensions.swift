import Foundation
import CommonCrypto

extension String {
    func flexMD5Upper() -> String {
        let data = Data(utf8)
        var digest = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
        data.withUnsafeBytes { buffer in
            _ = CC_MD5(buffer.baseAddress, CC_LONG(data.count), &digest)
        }
        return digest.map { String(format: "%02X", $0) }.joined()
    }
}

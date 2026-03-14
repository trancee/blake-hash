import Foundation

func hexToBytes(_ hex: String) -> [UInt8] {
    var bytes = [UInt8]()
    var i = hex.startIndex
    while i < hex.endIndex {
        let next = hex.index(i, offsetBy: 2)
        bytes.append(UInt8(hex[i..<next], radix: 16)!)
        i = next
    }
    return bytes
}

func toHex(_ bytes: [UInt8]) -> String {
    bytes.map { String(format: "%02x", $0) }.joined()
}

func blake3Input(_ n: Int) -> [UInt8] {
    (0..<n).map { UInt8($0 % 251) }
}

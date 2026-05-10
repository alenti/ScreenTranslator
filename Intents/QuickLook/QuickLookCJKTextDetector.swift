import Foundation

struct QuickLookCJKTextDetector {
    func containsCJK(in text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            isCJKUnifiedIdeograph(scalar)
        }
    }

    private func isCJKUnifiedIdeograph(
        _ scalar: Unicode.Scalar
    ) -> Bool {
        switch scalar.value {
        case 0x3400...0x4DBF,
             0x4E00...0x9FFF,
             0xF900...0xFAFF,
             0x20000...0x2A6DF,
             0x2A700...0x2B73F,
             0x2B740...0x2B81F,
             0x2B820...0x2CEAF,
             0x2F800...0x2FA1F:
            return true
        default:
            return false
        }
    }
}

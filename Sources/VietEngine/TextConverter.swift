import Foundation

/// Chuyển đổi văn bản cho tính năng "chuyển mã clipboard".
public enum TextConverter {
    /// Bỏ dấu: "Tiếng Việt" → "Tieng Viet".
    public static func removeDiacritics(_ s: String) -> String {
        s.precomposedStringWithCanonicalMapping
            .replacingOccurrences(of: "đ", with: "d").replacingOccurrences(of: "Đ", with: "D")
            .folding(options: .diacriticInsensitive, locale: Locale(identifier: "vi"))
    }

    /// Unicode tổ hợp (NFD, hay gặp khi copy từ PDF/macOS Finder) → dựng sẵn (NFC).
    public static func precomposed(_ s: String) -> String { s.precomposedStringWithCanonicalMapping }

    public static func uppercased(_ s: String) -> String { s.uppercased(with: Locale(identifier: "vi")) }
    public static func lowercased(_ s: String) -> String { s.lowercased(with: Locale(identifier: "vi")) }
    /// Viết hoa chữ đầu mỗi từ: "tiếng việt" → "Tiếng Việt".
    public static func titleCased(_ s: String) -> String { s.capitalized(with: Locale(identifier: "vi")) }

    // MARK: - TCVN3 (ABC): mỗi chữ có dấu là một byte, hiện thành ký tự Latin-1 khi dán ra Unicode

    private static let tcvn3: [Character: Character] = {
        let codes: [UInt32] = [
            0xA8, 0xA9, 0xAA, 0xAB, 0xAC, 0xAD, 0xAE,          // ă â ê ô ơ ư đ
            0xA1, 0xA2, 0xA3, 0xA4, 0xA5, 0xA6, 0xA7,          // Ă Â Ê Ô Ơ Ư Đ
            0xB5, 0xB6, 0xB7, 0xB8, 0xB9,                      // à ả ã á ạ
            0xBB, 0xBC, 0xBD, 0xBE, 0xC6,                      // ằ ẳ ẵ ắ ặ
            0xC7, 0xC8, 0xC9, 0xCA, 0xCB,                      // ầ ẩ ẫ ấ ậ
            0xCC, 0xCE, 0xCF, 0xD0, 0xD1,                      // è ẻ ẽ é ẹ
            0xD2, 0xD3, 0xD4, 0xD5, 0xD6,                      // ề ể ễ ế ệ
            0xD7, 0xD8, 0xDC, 0xDD, 0xDE,                      // ì ỉ ĩ í ị
            0xDF, 0xE1, 0xE2, 0xE3, 0xE4,                      // ò ỏ õ ó ọ
            0xE5, 0xE6, 0xE7, 0xE8, 0xE9,                      // ồ ổ ỗ ố ộ
            0xEA, 0xEB, 0xEC, 0xED, 0xEE,                      // ờ ở ỡ ớ ợ
            0xEF, 0xF1, 0xF2, 0xF3, 0xF4,                      // ù ủ ũ ú ụ
            0xF5, 0xF6, 0xF7, 0xF8, 0xF9,                      // ừ ử ữ ứ ự
            0xFA, 0xFB, 0xFC, 0xFD, 0xFE,                      // ỳ ỷ ỹ ý ỵ
        ]
        let uni = Array("ăâêôơưđĂÂÊÔƠƯĐàảãáạằẳẵắặầẩẫấậèẻẽéẹềểễếệìỉĩíịòỏõóọồổỗốộờởỡớợùủũúụừửữứựỳỷỹýỵ")
        precondition(codes.count == uni.count)
        var d: [Character: Character] = [:]
        for (c, u) in zip(codes, uni) { d[Character(Unicode.Scalar(c)!)] = u }
        return d
    }()

    public static func fromTCVN3(_ s: String) -> String {
        String(s.map { tcvn3[$0] ?? $0 })
    }

    // MARK: - VNI-Windows: chữ gốc + ký tự dấu đứng sau ("Vieät" = "Việt")

    private static let vni: (pairs: [String: Character], singles: [Character: Character]) = {
        // Ký tự dấu thanh theo thứ tự: không, sắc, huyền, hỏi, ngã, nặng
        let tone = (lower: ["", "ù", "ø", "û", "õ", "ï"], upper: ["", "Ù", "Ø", "Û", "Õ", "Ï"])
        let circ = (lower: ["â", "á", "à", "å", "ã", "ä"], upper: ["Â", "Á", "À", "Å", "Ã", "Ä"])
        let breve = (lower: ["ê", "é", "è", "ú", "ü", "ë"], upper: ["Ê", "É", "È", "Ú", "Ü", "Ë"])
        var pairs: [String: Character] = [:]
        func add(_ vniBase: String, base: Character, mark: Mark, marks: [String], upper: Bool) {
            for t in 0..<6 where !marks[t].isEmpty {
                var g = String(Glyphs.glyph(base: base, mark: mark, tone: Tone(rawValue: t)!))
                if upper { g = g.uppercased() }
                pairs[vniBase + marks[t]] = Character(g)
            }
        }
        for up in [false, true] {
            let tm = up ? tone.upper : tone.lower
            for b in "aeouy" { add(up ? b.uppercased() : String(b), base: b, mark: .none, marks: tm, upper: up) }
            add(up ? "Ô" : "ô", base: "o", mark: .horn, marks: tm, upper: up)   // ơ
            add(up ? "Ö" : "ö", base: "u", mark: .horn, marks: tm, upper: up)   // ư
            add(up ? "A" : "a", base: "a", mark: .circumflex, marks: up ? circ.upper : circ.lower, upper: up)
            add(up ? "E" : "e", base: "e", mark: .circumflex, marks: up ? circ.upper : circ.lower, upper: up)
            add(up ? "O" : "o", base: "o", mark: .circumflex, marks: up ? circ.upper : circ.lower, upper: up)
            add(up ? "A" : "a", base: "a", mark: .breve, marks: up ? breve.upper : breve.lower, upper: up)
        }
        let singles: [Character: Character] = [
            "í": "í", "ì": "ì", "æ": "ỉ", "ó": "ĩ", "ò": "ị", "Í": "Í", "Ì": "Ì", "Æ": "Ỉ", "Ó": "Ĩ", "Ò": "Ị",
            "ô": "ơ", "Ô": "Ơ", "ö": "ư", "Ö": "Ư", "î": "ỵ", "Î": "Ỵ", "ñ": "đ", "Ñ": "Đ",
        ]
        return (pairs, singles)
    }()

    public static func fromVNI(_ s: String) -> String {
        let cs = Array(s)
        var out = ""
        var i = 0
        while i < cs.count {
            if i + 1 < cs.count, let g = vni.pairs[String(cs[i]) + String(cs[i + 1])] {
                out.append(g); i += 2
            } else {
                out.append(vni.singles[cs[i]] ?? cs[i]); i += 1
            }
        }
        return out
    }
}

/// Gõ tắt: từ viết tắt → cụm từ đầy đủ. Giữ kiểu chữ hoa của từ đã gõ:
/// "vn" → "Việt Nam" (theo bảng), "VN" → "VIỆT NAM" nếu bảng chỉ có "vn", "Ko" → "Không" nếu bảng có "ko" → "không".
public enum Macro {
    public static func expand(_ word: String, table: [String: String]) -> String? {
        guard !word.isEmpty else { return nil }
        if let exact = table[word] { return exact }
        let lower = word.lowercased()
        guard let (_, value) = table.first(where: { $0.key.lowercased() == lower }) else { return nil }
        if word.count > 1 && word == word.uppercased() { return value.uppercased(with: Locale(identifier: "vi")) }
        if let f = word.first, f.isUppercase, let v = value.first {
            return String(v).uppercased(with: Locale(identifier: "vi")) + value.dropFirst()
        }
        return value
    }
}

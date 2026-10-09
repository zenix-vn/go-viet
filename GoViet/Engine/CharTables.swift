import Foundation

enum Mark { case none, circumflex, breve, horn, stroke }

public enum Tone: Int {
    case none = 0, acute, grave, hook, tilde, dot
}

struct GlyphKey: Hashable {
    let base: Character
    let mark: Mark
}

/// Bảng ký tự Unicode dựng sẵn (NFC): mỗi chữ có dấu là đúng 1 đơn vị UTF-16.
enum Glyphs {
    // Mỗi hàng: nguyên âm, dấu phụ, 6 dạng theo thanh (không, sắc, huyền, hỏi, ngã, nặng)
    static let rows: [(Character, Mark, String)] = [
        ("a", .none, "aáàảãạ"),
        ("a", .breve, "ăắằẳẵặ"),
        ("a", .circumflex, "âấầẩẫậ"),
        ("e", .none, "eéèẻẽẹ"),
        ("e", .circumflex, "êếềểễệ"),
        ("i", .none, "iíìỉĩị"),
        ("o", .none, "oóòỏõọ"),
        ("o", .circumflex, "ôốồổỗộ"),
        ("o", .horn, "ơớờởỡợ"),
        ("u", .none, "uúùủũụ"),
        ("u", .horn, "ưứừửữự"),
        ("y", .none, "yýỳỷỹỵ"),
    ]

    static let forward: [GlyphKey: [Character]] = {
        var d: [GlyphKey: [Character]] = [:]
        for (b, m, s) in rows { d[GlyphKey(base: b, mark: m)] = Array(s) }
        return d
    }()

    static let reverse: [Character: (base: Character, mark: Mark, tone: Tone)] = {
        var d: [Character: (Character, Mark, Tone)] = [:]
        for (b, m, s) in rows {
            for (i, c) in s.enumerated() { d[c] = (b, m, Tone(rawValue: i)!) }
        }
        d["đ"] = ("d", .stroke, .none)
        return d
    }()

    static func glyph(base: Character, mark: Mark, tone: Tone) -> Character {
        if let row = forward[GlyphKey(base: base, mark: mark)] { return row[tone.rawValue] }
        if base == "d" && mark == .stroke { return "đ" }
        return base
    }
}

struct Letter {
    var base: Character      // chữ thường, a-z
    var mark: Mark = .none
    var upper: Bool = false
    var fromW: Bool = false  // ư sinh ra từ phím w đứng riêng

    var isVowel: Bool { "aeiouy".contains(base) }
}

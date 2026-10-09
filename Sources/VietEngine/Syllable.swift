import Foundation

struct ParsedSyllable {
    var initialEnd: Int   // phụ âm đầu: [0, initialEnd)
    var nucleusEnd: Int   // vần: [initialEnd, nucleusEnd), âm cuối: [nucleusEnd, n)
}

enum Syllable {
    static let initials: Set<String> = [
        "", "b", "c", "ch", "d", "đ", "g", "gh", "gi", "h", "k", "kh", "l", "m", "n", "ng", "ngh",
        "nh", "p", "ph", "q", "qu", "r", "s", "t", "th", "tr", "v", "x",
    ]

    static let finals: Set<String> = ["", "c", "ch", "m", "n", "ng", "nh", "p", "t"]

    // Phần vần (nhóm nguyên âm), đã bỏ thanh. "ưo" là trạng thái trung gian khi đang gõ "ươ".
    static let nuclei: Set<String> = [
        "a", "ă", "â", "e", "ê", "i", "o", "ô", "ơ", "u", "ư", "y",
        "ai", "ao", "au", "âu", "ay", "ây", "eo", "êu", "ia", "iê", "iu", "oa", "oă", "oe", "oi",
        "ôi", "ơi", "ua", "uâ", "uê", "ui", "uy", "ưa", "ưi", "ưu", "uô", "uơ", "ươ", "yê", "ưo",
        "iêu", "yêu", "oai", "oay", "oeo", "uây", "uôi", "ươi", "ươu", "uyê", "uyu", "uêu",
    ]

    // Vần đang gõ dở (chưa gõ dấu mũ/móc): "uo" sắp thành "uô/ươ", "ie" sắp thành "iê"...
    // Chỉ hợp lệ khi chưa có dấu thanh, để chữ trên màn hình không nhảy qua lại giữa chữ gốc và chữ có dấu.
    static let partialNuclei: Set<String> = ["uo", "ie", "ye", "uye", "uoi", "ieu", "yeu", "uyeu", "uou"]

    static func parse(_ ls: [Letter]) -> ParsedSyllable {
        let n = ls.count
        var i = 0
        while i < n && !ls[i].isVowel { i += 1 }
        // "qu" là phụ âm đầu
        if i == 1, ls[0].base == "q", i < n, ls[1].base == "u", ls[1].mark == .none { i = 2 }
        // "gi" là phụ âm đầu khi theo sau còn nguyên âm (gia, giêng); "gì", "gìn" thì i là vần
        else if i == 1, ls[0].base == "g", i < n, ls[1].base == "i", n > 2, ls[2].isVowel { i = 2 }
        var j = i
        while j < n && ls[j].isVowel { j += 1 }
        return ParsedSyllable(initialEnd: i, nucleusEnd: j)
    }

    static func text(_ ls: ArraySlice<Letter>) -> String {
        String(ls.map { Glyphs.glyph(base: $0.base, mark: $0.mark, tone: .none) })
    }

    /// Âm tiết có thể là tiếng Việt hợp lệ (chấp nhận cả dạng đang gõ dở).
    static func isValid(_ ls: [Letter], tone: Tone) -> Bool {
        let p = parse(ls)
        let initial = text(ls[0..<p.initialEnd])
        guard initials.contains(initial) else { return false }
        if p.initialEnd == p.nucleusEnd {
            return p.nucleusEnd == ls.count && tone == .none
        }
        let nucleus = text(ls[p.initialEnd..<p.nucleusEnd])
        guard nuclei.contains(nucleus) || (tone == .none && partialNuclei.contains(nucleus)) else { return false }
        let fin = text(ls[p.nucleusEnd..<ls.count])
        guard finals.contains(fin) else { return false }

        // Hòa hợp giữa phụ âm đầu và vần
        let first = nucleus.first!
        let frontVowel = "eêiy".contains(first)
        switch initial {
        case "c", "ng", "q": if frontVowel { return false }
        case "g": if frontVowel && first != "i" { return false }   // "gì", "gìn"
        case "k", "gh", "ngh": if !frontVowel { return false }
        default: break
        }
        // Âm cuối ch, nh chỉ đi với a, ê, i, y
        if fin == "ch" || fin == "nh" {
            guard let last = nucleus.last, "aêiy".contains(last) else { return false }
        }
        // Âm cuối c, ch, p, t chỉ mang thanh sắc hoặc nặng
        if ["c", "ch", "p", "t"].contains(fin), tone != .none, tone != .acute, tone != .dot { return false }
        return true
    }

    /// Vị trí chữ mang dấu thanh.
    static func tonePosition(_ ls: [Letter], modern: Bool) -> Int? {
        let p = parse(ls)
        let nuc = Array(p.initialEnd..<p.nucleusEnd)
        if nuc.isEmpty { return nil }
        if nuc.count == 1 { return nuc[0] }
        if let marked = nuc.last(where: { ls[$0].mark != .none }) { return marked }
        if p.nucleusEnd < ls.count { return nuc.last }
        if nuc.count >= 3 { return nuc[1] }
        if modern, ["oa", "oe", "uy"].contains(text(ls[p.initialEnd..<p.nucleusEnd])) { return nuc[1] }
        return nuc[0]
    }
}

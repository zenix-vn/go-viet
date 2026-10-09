import Foundation

public struct EngineOptions: Equatable {
    /// true: kiểu mới (hoà, thuý). false: kiểu cũ (hòa, thúy).
    public var modernTone: Bool
    /// true: phím w đứng riêng thành ư.
    public var wToU: Bool

    public init(modernTone: Bool = false, wToU: Bool = true) {
        self.modernTone = modernTone
        self.wToU = wToU
    }
}

public enum EngineOutput: Equatable {
    /// Để phím gốc đi qua bình thường.
    case passThrough
    /// Nuốt phím gốc, xoá `delete` ký tự phía trước con trỏ rồi gõ `insert`.
    case replace(delete: Int, insert: String)
}

/// Engine Telex. Giữ một từ đang gõ; sau mỗi phím dựng lại chữ hiển thị
/// và trả về phần chênh lệch so với chữ đang có trên màn hình.
public final class TelexEngine {
    public var options: EngineOptions

    private var letters: [Letter] = []
    private var tone: Tone = .none
    private var raw: [Character] = []
    private var undone: Set<Character> = []
    /// Mọi phím đã gõ trong từ, đúng như người dùng bấm.
    private var typed: [Character] = []
    /// Đã có một phím dấu bị "ăn" khi huỷ (rr, ss, eee…) hoặc bị phím z xoá.
    private var droppedUndo = false
    /// Chữ của từ hiện đang nằm trên màn hình.
    public private(set) var displayed: [Character] = []

    public init(options: EngineOptions = EngineOptions()) {
        self.options = options
    }

    public var isEmpty: Bool { displayed.isEmpty }

    public func reset() {
        letters.removeAll(keepingCapacity: true)
        raw.removeAll(keepingCapacity: true)
        undone.removeAll(keepingCapacity: true)
        displayed.removeAll(keepingCapacity: true)
        typed.removeAll(keepingCapacity: true)
        droppedUndo = false
        justDropped = false
        tone = .none
    }

    // MARK: - Phím

    /// `ch` phải là một chữ cái ASCII a-z hoặc A-Z.
    /// Phím vừa xử lý đã "ăn" một phím dấu trước đó (lần huỷ dấu xảy ra đúng ở phím này).
    private var justDropped = false

    /// Phím đang xử lý đến sau một quãng dừng (người dùng nhìn màn hình rồi mới bấm).
    private var afterPause = false

    /// `afterPause`: phím này đến sau một quãng dừng rõ rệt so với phím trước (bộ gõ đo bằng thời gian sự kiện).
    /// Bấm lại phím dấu sau quãng dừng là chủ động bỏ dấu vừa thấy ("pú" → bấm s → "pus"), nên theo Telex chuẩn;
    /// bấm liền tay là chữ đôi tiếng Anh ("pass", "password", "offset") nên giữ nguyên phím đã gõ.
    public func handleLetter(_ ch: Character, afterPause: Bool = false) -> EngineOutput {
        self.afterPause = afterPause
        let prevDropped = justDropped
        justDropped = false
        // Không có từ tiếng Việt nào dài thế này (thường là giữ phím lặp): bắt đầu từ mới để bộ đệm không phình ra.
        if typed.count >= 32 { reset() }
        raw.append(ch)
        typed.append(ch)
        // Phím dấu gõ đôi rồi phụ âm (s-e-r-r-v-e-r, p-u-s-s-h): người dùng gõ đôi để bỏ dấu theo Telex,
        // nên giữ một chữ, không khôi phục nguyên phím đã gõ. Đánh đổi: "password", "offset" gõ liền
        // sẽ ra "pasword", "ofset" như Telex chuẩn (gõ "passsword" để có "password").
        let n = typed.count
        if droppedUndo, prevDropped, n >= 3, isDoubledToneKey(typed[n - 3], typed[n - 2]) {
            let next = Character(ch.lowercased())
            let rrh = typed[n - 2].lowercased() == "r" && next == "h"   // diarrhea, myrrh
            if !"aeiouy".contains(next) && !rrh { droppedUndo = false }
        }
        apply(key: Character(ch.lowercased()), upper: ch.isUppercase)
        let new = Array(render())
        let old = displayed
        displayed = new

        var common = 0
        while common < old.count, common < new.count, old[common] == new[common] { common += 1 }
        let del = old.count - common
        let ins = String(new[common...])
        if del == 0 && ins == String(ch) { return .passThrough }
        return .replace(delete: del, insert: ins)
    }

    /// Gọi khi người dùng bấm Backspace (phím vẫn đi qua bình thường).
    public func handleBackspace() {
        var chars = displayed
        guard !chars.isEmpty else { reset(); return }
        chars.removeLast()
        if chars.isEmpty { reset(); return }
        rebuild(from: chars)
    }

    // MARK: - Xử lý một phím

    private func literal(_ key: Character, _ upper: Bool) {
        letters.append(Letter(base: key, upper: upper))
    }

    private var hasVowel: Bool { letters.contains { $0.isVowel } }

    /// Từ đang hiển thị nguyên văn các phím đã gõ (không hợp lệ) mà người dùng gõ lại
    /// phím dấu lần nữa: coi như họ muốn đúng chữ đó ("class", chứ không phải "clas").
    private func restoreRaw() {
        letters = raw.map { Letter(base: Character($0.lowercased()), upper: $0.isUppercase) }
        tone = .none
    }

    /// Gõ phím dấu lần hai để huỷ ("rr" → "r"): phím đầu đã bị dấu "ăn", nên chữ gốc chỉ còn một phím đó.
    private func dropUndoneKey(_ key: Character) {
        justDropped = true
        if !afterPause { droppedUndo = true }
        let body = raw.dropLast()
        if let i = body.lastIndex(where: { Character($0.lowercased()) == key }) { raw.remove(at: i) }
    }

    private func apply(key: Character, upper: Bool) {
        if undone.contains(key) {
            // Gõ liền phím dấu lần thứ ba: người dùng chủ động muốn Telex chuẩn ("asss" → "ass"), bỏ quy tắc giữ nguyên.
            if typed.count >= 3,
               Character(typed[typed.count - 2].lowercased()) == key,
               Character(typed[typed.count - 3].lowercased()) == key {
                droppedUndo = false
            }
            return literal(key, upper)
        }
        let transformed = tone != .none || letters.contains { $0.mark != .none }
        let showingRaw = transformed && !Syllable.isValid(letters, tone: tone)

        switch key {
        case "s", "f", "r", "x", "j":
            let t: Tone = key == "s" ? .acute : key == "f" ? .grave : key == "r" ? .hook : key == "x" ? .tilde : .dot
            guard hasVowel else { return literal(key, upper) }
            if tone == t {
                undone.insert(key)
                if showingRaw { return restoreRaw() }
                dropUndoneKey(key)
                tone = .none
                literal(key, upper)
            } else {
                tone = t
            }

        case "z":
            if tone != .none {
                tone = .none
                droppedUndo = true   // z đã "ăn" phím dấu trước đó (authorize, size…)
            } else {
                literal(key, upper)
            }

        case "a", "e", "o":
            if let idx = letters.lastIndex(where: { $0.base == key }) {
                switch letters[idx].mark {
                case .none:
                    letters[idx].mark = .circumflex
                    return
                case .circumflex:
                    undone.insert(key)
                    if showingRaw { return restoreRaw() }
                    dropUndoneKey(key)
                    letters[idx].mark = .none
                default: break
                }
            }
            literal(key, upper)

        case "d":
            if let first = letters.first, first.base == "d" {
                if first.mark == .none {
                    letters[0].mark = .stroke
                    return
                } else if first.mark == .stroke {
                    undone.insert(key)
                    if showingRaw { return restoreRaw() }
                    dropUndoneKey(key)
                    letters[0].mark = .none
                }
            }
            literal(key, upper)

        case "w":
            applyW(upper, showingRaw: showingRaw)

        default:
            literal(key, upper)
        }
    }

    /// Chỉ số các chữ trong nhóm nguyên âm cuối cùng của từ.
    private func lastVowelGroup() -> [Int] {
        var i = letters.count - 1
        while i >= 0 && !letters[i].isVowel { i -= 1 }
        var group: [Int] = []
        while i >= 0 && letters[i].isVowel { group.insert(i, at: 0); i -= 1 }
        return group
    }

    private func afterQ(_ idx: Int) -> Bool { idx > 0 && letters[idx - 1].base == "q" }

    private func applyW(_ upper: Bool, showingRaw: Bool) {
        let group = lastVowelGroup()

        // "uo" + w → ươ
        for k in 0..<max(group.count - 1, 0) {
            let u = group[k], o = group[k + 1]
            guard letters[u].base == "u", letters[o].base == "o", o == u + 1, !afterQ(u) else { continue }
            guard [.none, .horn].contains(letters[u].mark), [.none, .horn].contains(letters[o].mark) else { continue }
            if letters[u].mark == .horn && letters[o].mark == .horn {
                undone.insert("w")
                if showingRaw { return restoreRaw() }
                dropUndoneKey("w")
                letters[u].mark = .none
                letters[o].mark = .none
                return literal("w", upper)
            }
            letters[u].mark = .horn
            letters[o].mark = .horn
            return
        }

        // a → ă, o → ơ, u → ư
        if let idx = group.last(where: { i in
            let b = letters[i].base
            return b == "a" || b == "o" || (b == "u" && !afterQ(i))
        }) {
            let want: Mark = letters[idx].base == "a" ? .breve : .horn
            if letters[idx].mark == want {
                if showingRaw {
                    undone.insert("w")
                    return restoreRaw()
                }
                dropUndoneKey("w")
                if letters[idx].fromW {
                    letters[idx] = Letter(base: "w", upper: letters[idx].upper)
                } else {
                    letters[idx].mark = .none
                    literal("w", upper)
                }
                undone.insert("w")
            } else {
                letters[idx].mark = want
            }
            return
        }

        if options.wToU {
            letters.append(Letter(base: "u", mark: .horn, upper: upper, fromW: true))
        } else {
            literal("w", upper)
        }
    }

    // MARK: - Dựng chữ hiển thị

    private func render() -> String {
        // Từ tiếng Anh có chữ đôi (Larry, coffee, array, error…): phím dấu bị huỷ mà từ không phải
        // tiếng Việt thì giữ nguyên các phím đã gõ. Từ ngắn (≤ 2 chữ, như "ass" → "as") vẫn theo Telex.
        // Phím dấu vừa gõ đôi xong: chưa biết sau đó là phụ âm (bỏ dấu: "puss" → "pus") hay nguyên âm
        // ("Larry", "assume"), nên tạm hiện kiểu Telex (một chữ) để màn hình không nhấp nháy.
        let n = typed.count
        let pendingDouble = justDropped && n >= 2 && isDoubledToneKey(typed[n - 2], typed[n - 1])
        if droppedUndo, !pendingDouble, letters.count >= 3, !Syllable.isValid(letters, tone: tone) { return String(typed) }
        let transformed = tone != .none || letters.contains { $0.mark != .none }
        if !transformed { return compose(tonePos: nil) }
        guard Syllable.isValid(letters, tone: tone) else { return String(raw) }
        let pos = Syllable.tonePosition(letters, modern: options.modernTone)
        if tone != .none && pos == nil { return String(raw) }
        return compose(tonePos: pos)
    }

    private func isDoubledToneKey(_ a: Character, _ b: Character) -> Bool {
        let x = Character(a.lowercased())
        return "sfrxj".contains(x) && x == Character(b.lowercased())
    }

    private func compose(tonePos: Int?) -> String {
        var out = ""
        for (i, l) in letters.enumerated() {
            let c = Glyphs.glyph(base: l.base, mark: l.mark, tone: i == tonePos ? tone : .none)
            out += l.upper ? String(c).uppercased() : String(c)
        }
        return out
    }

    /// Dựng lại trạng thái từ chữ đang hiển thị (sau Backspace), để gõ tiếp vẫn thêm dấu được.
    private func rebuild(from chars: [Character]) {
        letters.removeAll()
        undone.removeAll()
        tone = .none
        for c in chars {
            let lower = Character(c.lowercased())
            if let g = Glyphs.reverse[lower] {
                letters.append(Letter(base: g.base, mark: g.mark, upper: c.isUppercase))
                if g.tone != .none { tone = g.tone }
            } else {
                letters.append(Letter(base: lower, upper: c.isUppercase))
            }
        }
        raw = chars
        typed = chars
        droppedUndo = false
        justDropped = false
        displayed = chars
    }
}

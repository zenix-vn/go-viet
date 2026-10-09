import Foundation
import VietEngine

/// Mô phỏng màn hình: gõ lần lượt từng ký tự, áp dụng kết quả của engine.
func type(_ keys: String, modern: Bool = false, wToU: Bool = true) -> String {
    let engine = TelexEngine(options: EngineOptions(modernTone: modern, wToU: wToU))
    var screen: [Character] = []
    var pause = false
    for ch in keys {
        if ch == "|" { pause = true; continue }      // "|": dừng tay trước phím tiếp theo
        defer { pause = false }
        if ch == "\u{8}" {                      // Backspace
            engine.handleBackspace()
            if !screen.isEmpty { screen.removeLast() }
        } else if ch.isASCII && ch.isLetter {
            switch engine.handleLetter(ch, afterPause: pause) {
            case .passThrough: screen.append(ch)
            case .replace(let d, let ins):
                screen.removeLast(d)
                screen.append(contentsOf: ins)
            }
        } else {
            engine.reset()
            screen.append(ch)
        }
    }
    return String(screen)
}

var failed = 0
var total = 0
func check(_ keys: String, _ expected: String, modern: Bool = false, wToU: Bool = true) {
    total += 1
    let got = type(keys, modern: modern, wToU: wToU)
    if got != expected {
        failed += 1
        let shown = keys.replacingOccurrences(of: "\u{8}", with: "<BS>")
        print("FAIL  \(shown)  →  \(got)   (mong đợi \(expected), modern=\(modern))")
    }
}

// Thanh và dấu mũ cơ bản
check("as", "á"); check("af", "à"); check("ar", "ả"); check("ax", "ã"); check("aj", "ạ")
check("aa", "â"); check("ee", "ê"); check("oo", "ô"); check("aw", "ă"); check("ow", "ơ"); check("uw", "ư")
check("dd", "đ"); check("DD", "Đ"); check("Dd", "Đ")
check("asz", "a")

// Từ thông dụng
check("nguowif", "người"); check("nguwowif", "người"); check("tieengs", "tiếng")
check("Vieetj", "Việt"); check("Nam", "Nam"); check("truowngf", "trường"); check("Truowngf", "Trường")
check("quoocs", "quốc"); check("gias", "giá"); check("gif", "gì"); check("ddaayf", "đầy")
check("DDaau", "Đâu"); check("ddi", "đi"); check("did", "đi")
check("toans", "toán"); check("hoanf", "hoàn"); check("khuyeens", "khuyến")
check("chuyeenj", "chuyện"); check("ngoaif", "ngoài"); check("muwaf", "mừa"); check("duwowngj", "dượng")
check("nhuwngx", "những"); check("chaof", "chào"); check("cuar", "của"); check("mias", "mía")
check("thanhf", "thành"); check("hocj", "học"); check("khoong", "không")
check("giuwx", "giữ"); check("giuwxf", "giừ"); check("ghes", "ghé"); check("kys", "ký")
check("ngheej", "nghệ"); check("hocj", "học"); check("quyeenf", "quyền"); check("ddieeuf", "điều")
check("yeeus", "yếu"); check("uoongs", "uống"); check("buoonf", "buồn")
check("ddoongs", "đống"); check("nguyeenx", "nguyễn"); check("Hoafng", "Hoàng")

// Kiểu đặt dấu cũ / mới
check("hoaf", "hòa"); check("hoaf", "hoà", modern: true)
check("thuys", "thúy"); check("thuys", "thuý", modern: true)
check("khoer", "khỏe"); check("khoer", "khoẻ", modern: true)
check("hoaj", "họa"); check("hoaj", "hoạ", modern: true)
check("mias", "mía", modern: true); check("cuar", "của", modern: true)

check("dduowcj", "được"); check("dduocwj", "được"); check("dduwowcj", "được"); check("ddieeuf", "điều")

// Dấu gõ tự do (thanh trước, mũ sau)
check("tieesng", "tiếng"); check("tiengse", "tiếng")
check("hoanf", "hoàn"); check("hoafn", "hoàn")

// Gõ hai lần để huỷ dấu
check("ass", "as"); check("aaa", "aa"); check("ddd", "dd"); check("ooo", "oo"); check("aww", "aw")
check("ww", "w"); check("asss", "ass")

// Từ không phải tiếng Việt phải giữ nguyên
check("text", "text"); check("class", "class"); check("windows", "windows"); check("Xcode", "Xcode")
check("fix", "fix"); check("next", "next"); check("world", "world"); check("swift", "swift")
check("github", "github"); check("email", "email"); check("service", "service")
check("w", "ư"); check("w", "w", wToU: false); check("nw", "nư")

check("Server", "Server"); check("server", "server"); check("never", "never")
// Từ ngắn (≤ 2 chữ sau khi huỷ) theo Telex chuẩn: "ass" → "as"
check("ass", "as"); check("off", "of"); check("per", "pẻ")
// Từ tiếng Anh có chữ đôi giữ nguyên như đã gõ
check("error", "error"); check("Larry", "Larry"); check("array", "array"); check("coffee", "coffee")
check("offer", "offer"); check("assume", "assume"); check("less", "les"); check("pass", "pas")
check("class", "class"); check("luwoif", "lười"); check("dduwocj", "được"); check("nguwoif", "người"); check("thuwong", "thương"); check("muwowif", "mười"); check("uwo", "ưo"); check("PUSSH", "PUSH"); check("SERRVER", "SERVER"); check("downward", "downward"); check("Warwick", "Warwick"); check("waxwing", "waxwing"); check("hertz", "hertz"); check("quartz", "quartz"); check("hocjz", "hoc"); check("buaw", "bưa"); check("chuawx", "chữa"); check("cuuws", "cứu"); check("huuw", "hưu"); check("quawn", "quăn"); check("hoawcs", "hoắc"); check("muwa", "mưa"); check("buawf", "bừa"); check("chuaww", "chuaw"); check("wweb", "web"); check("wwindows", "windows"); check("Wweb", "Web"); check("keeep", "keep"); check("booot", "boot"); check("Serrver", "Server"); check("pus|sh", "push"); check("pussh", "push"); check("Pussh", "Push"); check("passsword", "password")
check("password", "pasword"); check("offset", "ofset"); check("passs", "pass"); check("Ser|rver", "Server")
check("Lar|ry", "Lary"); check("serrver", "server"); check("Serrvice", "Service"); check("worrd", "word"); check("access", "access"); check("address", "address")
check("assess", "assess"); check("hello", "hello"); check("current", "current"); check("mirror", "mirror")
check("keeper", "keeper"); check("berseem", "berseem"); check("nongrooming", "nongrooming"); check("authorize", "authorize"); check("size", "size"); check("unfrozen", "unfrozen"); check("Saxonize", "Saxonize"); check("wordd", "wordd"); check("Larrry", "Larry"); check("Larrr", "Larr")

// Từ rất dài (giữ phím lặp) không làm hỏng engine
check(String(repeating: "x", count: 100) + " as", String(repeating: "x", count: 100) + " á")
check(String(repeating: "b", count: 40) + "as", String(repeating: "b", count: 40) + "as")

// Chữ hoa
check("Ow", "Ơ"); check("OW", "Ơ"); check("TIEENGS", "TIẾNG"); check("NGUOWIF", "NGƯỜI")

// Dấu câu và khoảng trắng kết thúc từ
check("tieengs Vieetj.", "tiếng Việt."); check("xin chaof, ", "xin chào, ")
check("as as", "á á"); check("hello1as", "hello1á")

// Backspace
check("tieengs\u{8}", "tiến"); check("tieengs\u{8}g", "tiếng")
check("hoaf\u{8}", "hò"); check("hoafn\u{8}n", "hoàn")
check("a\u{8}s", "s"); check("tieengs\u{8}\u{8}\u{8}", "ti")
check("Vieetj\u{8}ts", "Viết"); check("Vieetj\u{8}\u{8}ts", "Vít")

// Chuyển mã clipboard
func eq(_ got: String, _ want: String, _ label: String) {
    total += 1
    if got != want { failed += 1; print("FAIL  \(label): \(got)   (mong đợi \(want))") }
}
eq(TextConverter.removeDiacritics("Tiếng Việt Đà Nẵng"), "Tieng Viet Da Nang", "bỏ dấu")
eq(TextConverter.fromTCVN3("TiÕng ViÖt"), "Tiếng Việt", "TCVN3")
eq(TextConverter.fromTCVN3("Hµ Néi"), "Hà Nội", "TCVN3")
eq(TextConverter.fromTCVN3("\u{AE}\u{AD}\u{EE}c"), "được", "TCVN3")
eq(TextConverter.fromVNI("Tieáng Vieät"), "Tiếng Việt", "VNI")
eq(TextConverter.fromVNI("Haø Noäi"), "Hà Nội", "VNI")
eq(TextConverter.fromVNI("ñöôïc"), "được", "VNI")
eq(TextConverter.fromVNI("Ñoàng"), "Đồng", "VNI")
eq(TextConverter.fromVNI("VIEÄT NAM"), "VIỆT NAM", "VNI")
eq(TextConverter.fromVNI("Ñaø Naüng"), "Đà Nẵng", "VNI")
eq(TextConverter.fromVNI("thuyû"), "thuỷ", "VNI")
eq(TextConverter.precomposed("Vie\u{0302}\u{0323}t"), "Việt", "NFC")
eq(TextConverter.titleCased("tiếng việt"), "Tiếng Việt", "hoa đầu từ")
eq(TextConverter.uppercased("đường"), "ĐƯỜNG", "chữ hoa")

// Gõ tắt
let table = ["vn": "Việt Nam", "ko": "không", "VNĐ": "đồng"]
eq(Macro.expand("vn", table: table) ?? "nil", "Việt Nam", "gõ tắt")
eq(Macro.expand("VN", table: table) ?? "nil", "VIỆT NAM", "gõ tắt HOA")
eq(Macro.expand("Ko", table: table) ?? "nil", "Không", "gõ tắt Hoa đầu")
eq(Macro.expand("VNĐ", table: table) ?? "nil", "đồng", "gõ tắt khớp đúng")
eq(Macro.expand("abc", table: table) ?? "nil", "nil", "không có gõ tắt")

print(failed == 0 ? "OK: \(total)/\(total) ca kiểm thử đạt" : "THẤT BẠI: \(failed)/\(total)")
exit(failed == 0 ? 0 : 1)

// Palette file (.mpal) reader.
// An .mpal is a zip: META-INF/container.xml -> palette.xml (<Palette><Cell>…).
import Foundation
import Compression

public struct MpalError: LocalizedError {
    public let errorDescription: String?
    init(_ msg: String) { errorDescription = msg }
}

public enum Mpal {
    /// Renders an .mpal archive as a self-contained HTML page.
    public static func html(fromArchive data: Data) throws -> String {
        try renderHTML(paletteXML(fromArchive: data))
    }

    /// Returns the palette XML (the container's root file, usually palette.xml).
    public static func paletteXML(fromArchive data: Data) throws -> Data {
        let files = try unzip(data)
        let root = files["META-INF/container.xml"].flatMap(rootPath) ?? "palette.xml"
        guard let xml = files[root] else { throw MpalError("\(root) not found in archive") }
        return xml
    }
}

// MARK: - Container

private func rootPath(_ data: Data) -> String? {
    guard let doc = try? XMLDocument(data: data),
          let el = (try? doc.nodes(forXPath: "//rootfile"))?.first as? XMLElement
    else { return nil }
    return el.attribute(forName: "full-path")?.stringValue
}

// MARK: - Minimal zip reader (stored + deflate). Palettes are tiny, so read everything.

private func unzip(_ data: Data) throws -> [String: Data] {
    let b = [UInt8](data)
    func u16(_ o: Int) throws -> Int {
        guard o >= 0, o + 2 <= b.count else { throw MpalError("Truncated zip") }
        return Int(b[o]) | Int(b[o + 1]) << 8
    }
    func u32(_ o: Int) throws -> Int { try u16(o) | u16(o + 2) << 16 }

    // End of central directory record (scan back over an optional comment).
    var eocd = b.count - 22
    while eocd >= 0, try u32(eocd) != 0x0605_4b50 { eocd -= 1 }
    guard eocd >= 0 else { throw MpalError("Not a zip archive") }

    var p = try u32(eocd + 16)
    var out: [String: Data] = [:]
    for _ in 0..<(try u16(eocd + 10)) {
        guard try u32(p) == 0x0201_4b50 else { throw MpalError("Bad central directory") }
        let method = try u16(p + 10), csize = try u32(p + 20), usize = try u32(p + 24)
        let nlen = try u16(p + 28), xlen = try u16(p + 30), clen = try u16(p + 32)
        let local = try u32(p + 42)
        guard p + 46 + nlen <= b.count else { throw MpalError("Truncated zip") }
        let name = String(decoding: b[(p + 46)..<(p + 46 + nlen)], as: UTF8.self)
        p += 46 + nlen + xlen + clen

        guard try u32(local) == 0x0403_4b50 else { throw MpalError("Bad local header") }
        let start = try local + 30 + u16(local + 26) + u16(local + 28)
        guard start + csize <= b.count else { throw MpalError("Truncated zip") }
        let src = Array(b[start..<(start + csize)])
        switch method {
        case 0: out[name] = Data(src)
        case 8: out[name] = try inflate(src, size: usize)
        default: continue
        }
    }
    return out
}

private func inflate(_ src: [UInt8], size: Int) throws -> Data {
    guard size > 0 else { return Data() }
    guard size < 50_000_000 else { throw MpalError("Entry too large") }
    var dst = [UInt8](repeating: 0, count: size)
    // COMPRESSION_ZLIB is raw DEFLATE (RFC 1951), which is exactly zip method 8.
    let n = compression_decode_buffer(&dst, size, src, src.count, nil, COMPRESSION_ZLIB)
    guard n == size else { throw MpalError("Inflate failed") }
    return Data(dst)
}

// MARK: - Palette -> HTML

private func renderHTML(_ xml: Data) throws -> String {
    let doc = try XMLDocument(data: xml)
    let palette = try doc.nodes(forXPath: "//Palette").first as? XMLElement
    func field(_ n: String) -> String? { palette?.elements(forName: n).first?.stringValue }

    let title = palette?.attribute(forName: "name")?.stringValue ?? "Palette"
    let version = doc.rootElement()?.attribute(forName: "version")?.stringValue ?? "?"
    let cells = try doc.nodes(forXPath: "//Palette/Cell").compactMap { $0 as? XMLElement }

    let items = cells.map { cell -> String in
        // The cell's element is its first child that has children (e.g. <Sticking>, <Articulation>);
        // skip plain scalar settings such as <mag> or <xoffset>.
        let kids = cell.children?.compactMap { $0 as? XMLElement } ?? []
        let el = kids.first { k in (k.children ?? []).contains { $0 is XMLElement } } ?? kids.first
        let type = el?.name ?? "Empty"
        let glyph = el?.elements(forName: "text").first?.stringValue
            ?? el?.elements(forName: "subtype").first?.stringValue ?? type
        let font = el?.elements(forName: "family").first?.stringValue
        let style = font.map { " style=\"font-family:'\(esc($0))',serif\"" } ?? ""
        let small = glyph.count > 3 ? " s" : ""
        let name = cell.attribute(forName: "name")?.stringValue ?? ""
        return """
        <div class="cell"><div class="g\(small)"\(style)>\(esc(glyph))</div>\
        <div class="n">\(esc(name))</div><div class="t">\(esc(type))</div></div>
        """
    }.joined(separator: "\n")

    var meta = ["\(cells.count) cell\(cells.count == 1 ? "" : "s")", "format \(version)"]
    if let w = field("gridWidth"), let h = field("gridHeight") { meta.append("grid \(w)×\(h)") }
    if let t = field("type") { meta.append(t) }

    return """
    <!doctype html><html><head><meta charset="utf-8"><title>\(esc(title))</title><style>
    :root{color-scheme:light dark;--bg:#fff;--fg:#1d1d1f;--mut:#6e6e73;--card:#f5f5f7;--line:#d2d2d7}
    @media(prefers-color-scheme:dark){:root{--bg:#1e1e1e;--fg:#f5f5f7;--mut:#a1a1a6;--card:#2c2c2e;--line:#3a3a3c}}
    body{margin:0;padding:24px;font:13px -apple-system,system-ui,sans-serif;background:var(--bg);color:var(--fg)}
    h1{font-size:20px;margin:0 0 4px}.meta{color:var(--mut);margin-bottom:18px}
    .grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(120px,1fr));gap:10px}
    .cell{background:var(--card);border:1px solid var(--line);border-radius:10px;padding:12px 8px;text-align:center}
    .g{font-size:34px;height:48px;line-height:48px;overflow:hidden;white-space:nowrap;text-overflow:ellipsis}
    .g.s{font-size:12px;color:var(--mut)}.n{font-weight:600;margin-top:6px}.t{color:var(--mut);font-size:11px}
    </style></head><body>
    <h1>\(esc(title))</h1><div class="meta">\(esc(meta.joined(separator: " · ")))</div>
    <div class="grid">
    \(items.isEmpty ? "<p>No cells.</p>" : items)
    </div></body></html>
    """
}

private func esc(_ s: String) -> String {
    s.replacingOccurrences(of: "&", with: "&amp;")
        .replacingOccurrences(of: "<", with: "&lt;")
        .replacingOccurrences(of: ">", with: "&gt;")
        .replacingOccurrences(of: "\"", with: "&quot;")
        .replacingOccurrences(of: "'", with: "&#39;")
}

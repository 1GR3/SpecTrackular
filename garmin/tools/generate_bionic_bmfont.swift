import AppKit
import CoreText

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let sourceFont = root.appendingPathComponent("resources/Bionic_Bold_Number_Only.ttf")
let outputDir = root.appendingPathComponent("resources/fonts")
let pngName = "BionicBoldNumber.png"
let fntName = "BionicBoldNumber.fnt"
let glyphs = Array("0123456789%-")
let fontSize: CGFloat = 28
let padding: CGFloat = 2

try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

var error: Unmanaged<CFError>?
CTFontManagerRegisterFontsForURL(sourceFont as CFURL, .process, &error)

guard let descriptors = CTFontManagerCreateFontDescriptorsFromURL(sourceFont as CFURL) as? [CTFontDescriptor],
      let descriptor = descriptors.first else {
    fatalError("Could not read font descriptor")
}

let ctFont = CTFontCreateWithFontDescriptor(descriptor, fontSize, nil)
let fontName = CTFontCopyPostScriptName(ctFont) as String
let lineHeight = ceil(CTFontGetAscent(ctFont) + CTFontGetDescent(ctFont) + CTFontGetLeading(ctFont) + padding * 2)
let base = ceil(CTFontGetAscent(ctFont) + padding)

struct GlyphInfo {
    let char: Character
    let id: UInt32
    let x: Int
    let y: Int
    let width: Int
    let height: Int
    let xAdvance: Int
}

var entries: [GlyphInfo] = []
var cursor = Int(padding)

for char in glyphs {
    let string = String(char)
    let attr = NSAttributedString(string: string, attributes: [
        .font: ctFont,
        .foregroundColor: NSColor.white
    ])
    let line = CTLineCreateWithAttributedString(attr)
    let advance = ceil(CTLineGetTypographicBounds(line, nil, nil, nil))
    let width = max(1, Int(advance + padding * 2))
    entries.append(GlyphInfo(
        char: char,
        id: string.unicodeScalars.first!.value,
        x: cursor,
        y: 0,
        width: width,
        height: Int(lineHeight),
        xAdvance: Int(advance)
    ))
    cursor += width
}

let atlasWidth = cursor + Int(padding)
let atlasHeight = Int(lineHeight)
let colorSpace = CGColorSpaceCreateDeviceRGB()
let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue

guard let context = CGContext(
    data: nil,
    width: atlasWidth,
    height: atlasHeight,
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: colorSpace,
    bitmapInfo: bitmapInfo
) else {
    fatalError("Could not create bitmap context")
}

context.clear(CGRect(x: 0, y: 0, width: atlasWidth, height: atlasHeight))
context.setFillColor(NSColor.white.cgColor)
context.textMatrix = .identity

for entry in entries {
    let attr = NSAttributedString(string: String(entry.char), attributes: [
        .font: ctFont,
        .foregroundColor: NSColor.white
    ])
    let line = CTLineCreateWithAttributedString(attr)
    context.textPosition = CGPoint(x: CGFloat(entry.x) + padding, y: lineHeight - base)
    CTLineDraw(line, context)
}

guard let image = context.makeImage(),
      let destination = CGImageDestinationCreateWithURL(outputDir.appendingPathComponent(pngName) as CFURL, "public.png" as CFString, 1, nil) else {
    fatalError("Could not create PNG")
}
CGImageDestinationAddImage(destination, image, nil)
CGImageDestinationFinalize(destination)

var fnt = ""
fnt += "info face=\"\(fontName)\" size=\(Int(fontSize)) bold=0 italic=0 charset=\"\" unicode=1 stretchH=100 smooth=1 aa=1 padding=0,0,0,0 spacing=1,1 outline=0\n"
fnt += "common lineHeight=\(Int(lineHeight)) base=\(Int(base)) scaleW=\(atlasWidth) scaleH=\(atlasHeight) pages=1 packed=0 alphaChnl=1 redChnl=4 greenChnl=4 blueChnl=4\n"
fnt += "page id=0 file=\"\(pngName)\"\n"
fnt += "chars count=\(entries.count)\n"
for entry in entries {
    fnt += "char id=\(entry.id) x=\(entry.x) y=\(entry.y) width=\(entry.width) height=\(entry.height) xoffset=0 yoffset=0 xadvance=\(entry.xAdvance) page=0 chnl=15\n"
}
fnt += "kernings count=0\n"

try fnt.write(to: outputDir.appendingPathComponent(fntName), atomically: true, encoding: .utf8)

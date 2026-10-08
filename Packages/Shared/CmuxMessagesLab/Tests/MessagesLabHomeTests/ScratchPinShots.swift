import AppKit
import CmuxHomeCore
import CmuxHomeRender
import Testing
@testable import MessagesLabHome

/// SCRATCH (never landed): light and dark renders of the Home pane with an
/// agent's short Markdown and a drag selection, for the MessagesLab pin review.
@MainActor @Suite(.serialized) struct ScratchPinShots {
    static let agent = [
        "Plan: **ship the pin** after the `verify-clean` pass.",
        "Steps:\n- one *italic* step\n- a [link](https://cmux.com)\n- ~~old~~ new",
        "Select this sentence to check the highlight on the transcript.",
    ]

    private func render(dark: Bool) throws -> (CGImage, String) {
        let theme = dark
            ? HomePalette.Theme(background: .gray255(30), foreground: .gray255(235), accent: .rgb255(10, 132, 255), failure: .rgb255(255, 69, 58))
            : HomePalette.Theme(background: .gray255(255), foreground: .gray255(20), accent: .rgb255(0, 122, 255), failure: .rgb255(255, 59, 48))
        Fixture.theme = FixtureTheme(active: .themed(theme), inactive: .themed(theme, active: false))
        Fixture.lightAppearance = !dark
        RowBitmaps.shared.removeAll()
        let (p, c) = Fixture2.projection()
        var items = [Fixture2.item(1, Fixture2.me, "Status of the MessagesLab pin?")]
        for (i, t) in Self.agent.enumerated() { items.append(Fixture2.item(Seq(i + 2), Fixture2.them, t)) }
        items.append(Fixture2.item(5, Fixture2.me, "Thanks, **looks good** (mine stays plain)."))
        p.apply(items: items, summary: Fixture2.summary(lastSeq: 5), typing: [], hasOlder: false)
        c.demo.backgroundColor = Fixture.background
        c.host.layoutSubtreeIfNeeded(); c.demo.layoutIfNeeded(); c.demo.collection.layoutIfNeeded()
        let hit = try #require(c.demo.lastTextRow(mine: false))
        c.selection.mouseDown(CGPoint(x: hit.body.minX + 16, y: hit.body.minY + 14))
        _ = c.selection.mouseDragged(CGPoint(x: hit.body.maxX - 30, y: hit.body.maxY - 12))
        _ = c.selection.mouseUp()
        #expect(!c.selection.isEmpty, "the drag made a selection")
        let picked = c.selection.selectedRanges().map(\.text).joined()
        c.host.layoutSubtreeIfNeeded(); c.demo.collection.layoutIfNeeded()
        CATransaction.flush()
        let b = c.host.bounds
        let ctx = try #require(CGContext(data: nil, width: Int(b.width * 2), height: Int(b.height * 2), bitsPerComponent: 8,
                                         bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                         bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        ctx.scaleBy(x: 2, y: 2)
        ctx.setFillColor(Fixture.background.cgColor); ctx.fill(b)
        if c.host.isFlipped { ctx.translateBy(x: 0, y: b.height); ctx.scaleBy(x: 1, y: -1) }
        try #require(c.host.layer).render(in: ctx)
        return (try #require(ctx.makeImage()), picked)
    }

    @Test func lightAndDark() throws {
        let (light, l) = try render(dark: false)
        let (dark, d) = try render(dark: true)
        print("SCRATCH selected light: \(l.debugDescription) dark: \(d.debugDescription)")
        let w = light.width + dark.width, h = max(light.height, dark.height)
        let ctx = try #require(CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                                         space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        ctx.draw(light, in: CGRect(x: 0, y: 0, width: light.width, height: light.height))
        ctx.draw(dark, in: CGRect(x: light.width, y: 0, width: dark.width, height: dark.height))
        let rep = NSBitmapImageRep(cgImage: try #require(ctx.makeImage()))
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("../../../../../artifacts")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try #require(rep.representation(using: .png, properties: [:])).write(to: root.appendingPathComponent("mlpin-home.png"))
        print("SCRATCH wrote \(root.appendingPathComponent("mlpin-home.png").standardized.path)")
    }
}

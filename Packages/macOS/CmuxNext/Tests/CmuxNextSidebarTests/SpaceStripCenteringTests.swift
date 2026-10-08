import AppKit
import CmuxNextDesign
import Testing
@testable import CmuxNextSidebar

/// cx-5k3r (Lawrence 2026-10-08): "center spaces in bottom; spaces should
/// show better". The spaces strip in the footer row is centered on the
/// sidebar (measured from the laid-out slot frames), never covers the
/// profile control, stays inside the sidebar with many spaces, marks the
/// current space with a filled chip, and tells VoiceOver which one is
/// current. Lawrence (same day): "by default, spaces should only be visible
/// when i hover on sidebar. same as all the other buttons".
@MainActor @Suite(.serialized) struct SpaceStripCenteringTests {
    static let account = LayoutItemID("itm_account")

    private func sidebar(spaces: Int, width: CGFloat, active: Int = 0) -> SidebarView {
        let model = SidebarModel()
        model.profiles = (0..<spaces).map { SidebarProfile(id: ProfileKey("s\($0)"), name: "Space \($0)") }
        model.activeProfileID = ProfileKey("s\(active)")
        var info = SidebarBuiltIn.account.defaultInfo
        info.avatar = SidebarAvatar(name: "Work", color: nil)
        info.title = "Work"
        model.itemInfo = [Self.account: info]
        let view = SidebarView(model: model)
        view.frame = NSRect(x: 0, y: 0, width: width, height: 700)
        view.layoutSubtreeIfNeeded()
        view.layout()
        return view
    }

    private func controlFrame(_ view: SidebarView) throws -> NSRect {
        view.convert(try #require(view.footerRegion.itemView(Self.account)).frame, from: view.footerRegion)
    }

    @Test(arguments: [(2, 208.0), (3, 240.0), (3, 360.0), (4, 300.0)])
    func theStripIsCenteredOnTheSidebar(_ spaces: Int, _ width: Double) throws {
        let view = sidebar(spaces: spaces, width: width)
        let frames = view.shortcutHintSpaceFrames
        #expect(frames.count == spaces)
        let union = frames.dropFirst().reduce(try #require(frames.first)) { $0.union($1) }
        #expect(abs(union.midX - view.bounds.midX) <= 0.5, "strip \(union) in a \(width) pt sidebar (middle \(view.bounds.midX))")
        #expect(union.minX >= try controlFrame(view).maxX - 0.5, "the strip never covers the profile control")
    }

    @Test func manySpacesStayInsideTheSidebarAndOffTheControl() throws {
        let view = sidebar(spaces: 14, width: 208, active: 9)
        let frames = view.shortcutHintSpaceFrames
        #expect(frames.count == 14)
        let control = try controlFrame(view)
        for frame in frames {
            #expect(frame.minX >= control.maxX - 0.5 && frame.maxX <= view.bounds.maxX + 0.5, "\(frame) in \(view.bounds)")
        }
        for (a, b) in zip(frames, frames.dropFirst()) { #expect(a.maxX <= b.minX + 0.5, "slots overlap: \(a) \(b)") }
        // The current space keeps a full slot.
        #expect(frames[9].width >= Metrics.roomDotSlot - 0.5)
    }

    /// The current space sits on a filled chip (not only a stronger dot):
    /// a pixel in the chip's corner area, away from the mark, is painted
    /// for the current space and empty for the others.
    @Test func theCurrentSpaceSitsOnAFilledChip() throws {
        let view = sidebar(spaces: 3, width: 260, active: 1)
        let bar = view.profileBar
        let rep = try #require(bar.bitmapImageRepForCachingDisplay(in: bar.bounds))
        bar.cacheDisplay(in: bar.bounds, to: rep)
        let scale = CGFloat(rep.pixelsWide) / bar.bounds.width
        func alpha(nearLeadingEdgeOf index: Int) -> CGFloat {
            let slot = bar.convert(view.shortcutHintSpaceFrames[index], from: view)
            let x = Int((slot.minX + Metrics.space1 + 3) * scale), y = Int(bar.bounds.midY * scale)
            return rep.colorAt(x: x, y: y)?.alphaComponent ?? 0
        }
        #expect(alpha(nearLeadingEdgeOf: 1) > 0.02, "the current space has a chip")
        #expect(alpha(nearLeadingEdgeOf: 0) <= 0.02 && alpha(nearLeadingEdgeOf: 2) <= 0.02, "the others do not")
    }

    @Test func voiceOverMarksTheCurrentSpaceSelected() throws {
        let view = sidebar(spaces: 3, width: 260, active: 2)
        let children = try #require(view.profileBar.accessibilityChildren() as? [NSAccessibilityElement])
        #expect(children.count == 4, "three spaces and New Space")
        #expect(children.map { $0.isAccessibilitySelected() } == [false, false, true, false])
        #expect(children[2].accessibilityLabel() == "Space 2, current space")
        #expect(children[0].accessibilityLabel() == "Space 0")
    }

    /// By default the strip shows only while the sidebar is hovered, with
    /// the sidebar's other hover chrome (one shared reveal state). It fades;
    /// it is never removed, so VoiceOver still reaches it.
    @Test func theStripShowsOnlyWhileTheSidebarIsHovered() throws {
        let design = DesignSettings.shared
        let saved = design.animationSpeed
        defer { design.animationSpeed = saved }
        design.animationSpeed = .off
        let view = sidebar(spaces: 3, width: 260)
        #expect(!view.isChromeRevealed)
        #expect(view.profileBar.alphaValue == 0, "hidden at rest")
        #expect(!view.profileBar.isHidden && view.profileBar.isAccessibilityElement())
        view.setChromeRevealed(true)
        #expect(view.profileBar.alphaValue == 1, "shown with the sidebar's hover chrome")
        #expect(view.newButton.alphaValue == 1)
        view.setChromeRevealed(false)
        #expect(view.profileBar.alphaValue == 0)
    }
}

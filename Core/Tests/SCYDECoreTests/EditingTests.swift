import XCTest
@testable import SCYDECore

final class EditingTests: XCTestCase {

    private func makeProject() -> (Project, UUID, UUID) {
        var p = Project(name: "T", now: Date(timeIntervalSince1970: 1_700_000_000))
        let a = p.addClip(Clip(kind: .video, name: "A", sourceDuration: 10, duration: 4), role: .main)
        let b = p.addClip(Clip(kind: .video, name: "B", sourceDuration: 10, duration: 3), role: .main)
        return (p, a, b)
    }

    func testAppendPlacesClipsBackToBack() {
        let (p, a, b) = makeProject()
        XCTAssertEqual(p.clip(a)?.start, 0)
        XCTAssertEqual(p.clip(b)?.start, 4)
        XCTAssertEqual(p.duration, 7, accuracy: 1e-9)
    }

    func testSplitCreatesTwoClipsWithCorrectSourceOffsets() {
        var (p, a, _) = makeProject()
        let rightID = p.split(a, at: 1.5)
        XCTAssertNotNil(rightID)
        let left = p.clip(a)!
        let right = p.clip(rightID!)!
        XCTAssertEqual(left.duration, 1.5, accuracy: 1e-9)
        XCTAssertEqual(right.start, 1.5, accuracy: 1e-9)
        XCTAssertEqual(right.duration, 2.5, accuracy: 1e-9)
        XCTAssertEqual(right.sourceIn, 1.5, accuracy: 1e-9)
        XCTAssertEqual(p.duration, 7, accuracy: 1e-9)
    }

    func testSplitRejectsEdgesAndOutsideTimes() {
        var (p, a, _) = makeProject()
        XCTAssertNil(p.split(a, at: 0))
        XCTAssertNil(p.split(a, at: 0.05))
        XCTAssertNil(p.split(a, at: 4))
        XCTAssertNil(p.split(a, at: 9))
    }

    func testSplitRespectsSpeed() {
        var p = Project()
        let id = p.addClip(Clip(kind: .video, name: "Fast", sourceDuration: 20, duration: 5, speed: 2), role: .main)
        let right = p.split(id, at: 2)!
        XCTAssertEqual(p.clip(right)!.sourceIn, 4, accuracy: 1e-9)
    }

    func testDeleteWithoutRippleLeavesGap() {
        var (p, a, b) = makeProject()
        XCTAssertTrue(p.delete(a))
        XCTAssertEqual(p.clip(b)?.start, 4)
    }

    func testDeleteWithRippleClosesGap() {
        var (p, a, b) = makeProject()
        XCTAssertTrue(p.delete(a, ripple: true))
        XCTAssertEqual(p.clip(b)?.start ?? -1, 0, accuracy: 1e-9)
    }

    func testTrimTrailingShortensAndExtendsWithinSource() {
        var (p, a, _) = makeProject()
        XCTAssertTrue(p.trim(a, edge: .trailing, to: 2))
        XCTAssertEqual(p.clip(a)!.duration, 2, accuracy: 1e-9)
        // Cannot extend past the neighbour at 4 s even though the source has room.
        _ = p.trim(a, edge: .trailing, to: 9)
        XCTAssertEqual(p.clip(a)!.duration, 4, accuracy: 1e-9)
    }

    func testTrimLeadingAdvancesSourceIn() {
        var (p, _, b) = makeProject()
        XCTAssertTrue(p.trim(b, edge: .leading, to: 5))
        let c = p.clip(b)!
        XCTAssertEqual(c.start, 5, accuracy: 1e-9)
        XCTAssertEqual(c.sourceIn, 1, accuracy: 1e-9)
        XCTAssertEqual(c.duration, 2, accuracy: 1e-9)
    }

    func testTrimLeadingCannotRevealBeforeSourceStart() {
        var (p, a, _) = makeProject()
        _ = p.trim(a, edge: .leading, to: 1)
        _ = p.trim(a, edge: .leading, to: -5)
        let c = p.clip(a)!
        XCTAssertEqual(c.sourceIn, 0, accuracy: 1e-9)
        XCTAssertEqual(c.start, 0, accuracy: 1e-9)
    }

    func testTrimKeepsMinimumDuration() {
        var (p, a, _) = makeProject()
        _ = p.trim(a, edge: .trailing, to: 0)
        XCTAssertEqual(p.clip(a)!.duration, Project.minClipDuration, accuracy: 1e-9)
    }

    func testPhotoCanBeStretchedFreely() {
        var p = Project()
        let id = p.addClip(Clip(kind: .photo, name: "P", duration: 4), role: .main)
        XCTAssertTrue(p.trim(id, edge: .trailing, to: 12))
        XCTAssertEqual(p.clip(id)!.duration, 12, accuracy: 1e-9)
        XCTAssertEqual(p.clip(id)!.sourceIn, 0)
    }

    func testMoveSlidesToFreeSlotInsteadOfOverlapping() {
        var (p, a, b) = makeProject()
        // Dragging B on top of A should land it after A (nearest free edge).
        _ = p.move(b, toStart: 1)
        let cb = p.clip(b)!
        let ca = p.clip(a)!
        XCTAssertTrue(cb.start >= ca.end - 1e-9 || cb.end <= ca.start + 1e-9)
    }

    func testMoveClampsToZero() {
        var (p, _, b) = makeProject()
        _ = p.move(b, toStart: -3)
        XCTAssertGreaterThanOrEqual(p.clip(b)!.start, 0)
    }

    func testDuplicateGoesAfterOriginal() {
        var p = Project()
        let id = p.addClip(Clip(kind: .video, name: "A", sourceDuration: 5, duration: 2), role: .main)
        let copy = p.duplicate(id)!
        XCTAssertEqual(p.clip(copy)!.start, 2, accuracy: 1e-9)
        XCTAssertEqual(p.clipCount, 2)
    }

    func testVolumeClampsAndReportsChange() {
        var (p, a, _) = makeProject()
        XCTAssertTrue(p.setVolume(a, to: 0))
        XCTAssertFalse(p.setVolume(a, to: 0))
        XCTAssertTrue(p.setVolume(a, to: 9))
        XCTAssertEqual(p.clip(a)!.volume, 2, accuracy: 1e-9)
    }

    func testClipUnderPrefersMainTrack() {
        var (p, a, _) = makeProject()
        _ = p.addClip(Clip(kind: .audio, name: "Music", sourceDuration: 30, duration: 10), role: .audio, at: 0)
        XCTAssertEqual(p.clipUnder(1)?.id, a)
    }

    func testSnapFindsNearestTargetWithinThreshold() {
        let r = Project.snap(2.04, targets: [0, 2, 5], threshold: 0.1)
        XCTAssertTrue(r.snapped)
        XCTAssertEqual(r.time, 2, accuracy: 1e-9)
        XCTAssertFalse(Project.snap(3, targets: [0, 2, 5], threshold: 0.1).snapped)
    }

    func testSnapMoveAlignsClipEndToTarget() {
        let r = Project.snapMove(start: 1.96, duration: 2, targets: [4], threshold: 0.1)
        XCTAssertTrue(r.snapped)
        XCTAssertEqual(r.time, 2, accuracy: 1e-9)
    }
}

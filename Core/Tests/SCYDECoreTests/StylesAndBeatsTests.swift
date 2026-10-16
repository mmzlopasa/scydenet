import XCTest
@testable import SCYDECore

final class StylesAndBeatsTests: XCTestCase {

    func testInsertRippleShiftsLaterClips() {
        var p = Project()
        let a = p.addClip(Clip(kind: .video, name: "A", sourceDuration: 4, duration: 4), role: .main)
        let b = p.addClip(Clip(kind: .video, name: "B", sourceDuration: 3, duration: 3), role: .main)
        let s = p.insertRipple(Clip(kind: .photo, name: "S", duration: 2), role: .main, at: 4)
        XCTAssertEqual(p.clip(a)!.start, 0, accuracy: 1e-9)
        XCTAssertEqual(p.clip(s)!.start, 4, accuracy: 1e-9)
        XCTAssertEqual(p.clip(b)!.start, 6, accuracy: 1e-9)
        XCTAssertEqual(p.duration, 9, accuracy: 1e-9)
        let main = p.tracks.first { $0.role == .main }!
        XCTAssertEqual(main.clips.map { $0.name }, ["A", "S", "B"])
    }

    func testFreezeSplitsAndInsertsStill() {
        var p = Project()
        let a = p.addClip(Clip(kind: .video, name: "A", sourceDuration: 6, duration: 6), role: .main)
        p.updateClip(a) { $0.filter = "noir" }
        let still = p.freeze(a, at: 2, frameAssetID: "f.jpg", length: 3)
        XCTAssertNotNil(still)
        let main = p.tracks.first { $0.role == .main }!
        XCTAssertEqual(main.clips.count, 3)
        XCTAssertEqual(main.clips[1].kind, .photo)
        XCTAssertEqual(main.clips[1].filter, "noir")
        XCTAssertEqual(main.clips[1].start, 2, accuracy: 1e-9)
        XCTAssertEqual(main.clips[2].start, 5, accuracy: 1e-9)
        XCTAssertEqual(main.clips[2].sourceIn, 2, accuracy: 1e-9)
        XCTAssertEqual(p.duration, 9, accuracy: 1e-9)
    }

    func testMarkersToggleAndSnap() {
        var p = Project()
        p.toggleMarker(at: 1.5)
        p.toggleMarker(at: 3)
        XCTAssertEqual(p.markers ?? [], [1.5, 3])
        p.toggleMarker(at: 1.52)
        XCTAssertEqual(p.markers ?? [], [3])
        let r = Project.snap(2.97, targets: p.snapTargets(excluding: nil, playhead: 0), threshold: 0.1)
        XCTAssertTrue(r.snapped)
        XCTAssertEqual(r.time, 3, accuracy: 1e-9)
    }

    func testSyncToMarkersCutsOnBeats() {
        var p = Project()
        p.addClip(Clip(kind: .photo, name: "P1", assetID: "1.jpg", duration: 3), role: .main)
        p.addClip(Clip(kind: .photo, name: "P2", assetID: "2.jpg", duration: 3), role: .main)
        p.addClip(Clip(kind: .video, name: "V", assetID: "v.mov", sourceDuration: 0.5, duration: 0.5), role: .main)
        p.setMarkers([0.5, 1.0, 1.5, 2.0, 2.5, 3.0])
        XCTAssertTrue(p.syncToMarkers(minLength: 0.3))
        let clips = p.tracks.first { $0.role == .main }!.clips
        XCTAssertEqual(clips[0].start, 0, accuracy: 1e-9)
        XCTAssertEqual(clips[0].end, 0.5, accuracy: 1e-9)
        XCTAssertEqual(clips[1].end, 1.0, accuracy: 1e-9)
        // The video only has 0.5 s of source, so it cannot reach past it.
        XCTAssertEqual(clips[2].duration, 0.5, accuracy: 1e-9)
    }

    func testOldProjectJSONStillDecodes() throws {
        let p = Project(name: "Old")
        var json = String(data: try JSONEncoder().encode(p), encoding: .utf8)!
        json = json.replacingOccurrences(of: "\"sticker\"", with: "\"text\"")
        let decoded = try JSONDecoder().decode(Project.self, from: Data(json.utf8))
        XCTAssertNil(decoded.background)
        XCTAssertNil(decoded.markers)
    }

    func testTextStyleDecodesWithMissingKeys() throws {
        let json = #"{"font":"doto","color":16766826}"#
        let style = try JSONDecoder().decode(TextStyle.self, from: Data(json.utf8))
        XCTAssertEqual(style.font, "doto")
        XCTAssertEqual(style.color, 0xFFD76A)
        XCTAssertEqual(style.size, 1, accuracy: 1e-9)
        XCTAssertEqual(style.animIn, .none)
    }

    func testCentredCrop() {
        let c = CropRect.centred(ratio: 1, sourceRatio: 16.0 / 9.0)
        XCTAssertEqual(c.height, 1, accuracy: 1e-9)
        XCTAssertEqual(c.width, 9.0 / 16.0, accuracy: 1e-9)
        XCTAssertEqual(c.x, (1 - 9.0 / 16.0) / 2, accuracy: 1e-9)
        XCTAssertTrue(CropRect.full.isFull)
    }

    func testAdjustmentsNormalise() {
        var a = Adjustments()
        a.vignette = 0.001
        XCTAssertNotEqual(a, .neutral)
        XCTAssertEqual(a.normalised(), .neutral)
    }
}

final class CurvesAndRampsTests: XCTestCase {
    func testSpeedCurveSlicesSumToSource() {
        let slices = SpeedCurves.sourceSlices([1, 3, 1], segments: 24, sourceLength: 6)
        XCTAssertEqual(slices.reduce(0, +), 6, accuracy: 1e-9)
        XCTAssertGreaterThan(slices[12], slices[0])
    }

    func testSourceTimeFollowsCurveAndEnds() {
        var c = Clip(kind: .video, name: "V", sourceDuration: 10, start: 2, sourceIn: 1, duration: 4, speed: 1)
        XCTAssertEqual(c.sourceTime(at: 4), 3, accuracy: 1e-9)
        c.speedCurve = [0.5, 0.5, 4, 4]
        XCTAssertEqual(c.sourceTime(at: 2), 1, accuracy: 1e-9)
        XCTAssertEqual(c.sourceTime(at: 6), 5, accuracy: 1e-6)
        XCTAssertLessThan(c.sourceTime(at: 4), 3)
    }

    func testSplitDropsSpeedCurve() {
        var p = Project()
        let id = p.addClip(Clip(kind: .video, name: "V", sourceDuration: 10, duration: 10), role: .main)
        p.updateClip(id) { $0.speedCurve = [1, 2, 1] }
        let right = p.split(id, at: 5)!
        XCTAssertNil(p.clip(id)!.speedCurve)
        XCTAssertNil(p.clip(right)!.speedCurve)
    }

    func testMaskAndEffectRamps() {
        var c = Clip(kind: .video, name: "V", start: 0, duration: 2)
        c.mask = ClipMask(shape: .circle, size: 0.2)
        c.maskEnd = ClipMask(shape: .circle, size: 1.0)
        XCTAssertEqual(c.mask(at: 1)!.size, 0.6, accuracy: 1e-9)
        let e = VideoEffect(kind: "blur", intensity: 0, endIntensity: 1)
        XCTAssertEqual(e.intensity(at: 0.25), 0.25, accuracy: 1e-9)
    }

    func testStabilizationInterpolates() {
        let s = Stabilization(start: 1, rate: 10, dx: [0, 0.1], dy: [0, -0.2], zoom: 1.1)
        let (x, y) = s.offset(at: 1.05)
        XCTAssertEqual(x, 0.05, accuracy: 1e-6)
        XCTAssertEqual(y, -0.1, accuracy: 1e-6)
    }
}

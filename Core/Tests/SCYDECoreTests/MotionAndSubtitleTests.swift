import XCTest
@testable import SCYDECore

final class MotionAndSubtitleTests: XCTestCase {

    func testTransformWithoutKeyframesUsesStaticValue() {
        var c = Clip(kind: .video, name: "A", duration: 4)
        XCTAssertEqual(c.transform(at: 1), .identity)
        c.transform = ClipTransform(x: 0.2, scale: 1.5)
        XCTAssertEqual(c.transform(at: 3).scale, 1.5, accuracy: 1e-9)
    }

    func testKeyframesInterpolateAndClamp() {
        var c = Clip(kind: .video, name: "A", start: 10, duration: 4)
        c.keyframes = [
            Keyframe(time: 1, transform: ClipTransform(scale: 1)),
            Keyframe(time: 3, transform: ClipTransform(scale: 2)),
        ]
        XCTAssertEqual(c.transform(at: 10).scale, 1, accuracy: 1e-9)
        XCTAssertEqual(c.transform(at: 12).scale, 1.5, accuracy: 1e-9) // midpoint, smoothstep(0.5) = 0.5
        XCTAssertEqual(c.transform(at: 14).scale, 2, accuracy: 1e-9)
        XCTAssertGreaterThan(c.transform(at: 11.5).scale, 1)
        XCTAssertLessThan(c.transform(at: 11.5).scale, 1.25)
    }

    func testSetKeyframeReplacesNearbyAndRemoves() {
        var p = Project()
        let id = p.addClip(Clip(kind: .video, name: "A", sourceDuration: 10, duration: 5), role: .main)
        XCTAssertTrue(p.setKeyframe(id, at: 1, transform: ClipTransform(x: 0.1)))
        XCTAssertTrue(p.setKeyframe(id, at: 1.02, transform: ClipTransform(x: 0.3)))
        XCTAssertEqual(p.clip(id)!.keyframes!.count, 1)
        XCTAssertEqual(p.clip(id)!.keyframes![0].transform.x, 0.3, accuracy: 1e-9)
        XCTAssertTrue(p.setKeyframe(id, at: 3, transform: ClipTransform(x: 0.5)))
        XCTAssertTrue(p.removeKeyframe(id, near: 1))
        XCTAssertEqual(p.clip(id)!.keyframes!.count, 1)
        XCTAssertTrue(p.removeKeyframe(id, near: 3))
        XCTAssertNil(p.clip(id)!.keyframes)
    }

    func testSplitShiftsKeyframesIntoRightClip() {
        var p = Project()
        let id = p.addClip(Clip(kind: .video, name: "A", sourceDuration: 10, duration: 6), role: .main)
        p.setKeyframe(id, at: 4, transform: ClipTransform(scale: 2))
        let right = p.split(id, at: 3)!
        XCTAssertEqual(p.clip(right)!.keyframes![0].time, 1, accuracy: 1e-9)
    }

    func testSRTRoundTrip() {
        var p = Project()
        p.addClip(Clip(kind: .text, name: "c", duration: 1.5, text: "Hello there"), role: .text, at: 0.5)
        p.addClip(Clip(kind: .text, name: "c", duration: 2, text: "Second line"), role: .text, at: 62.25)
        let srt = Subtitles.srt(from: p)
        XCTAssertTrue(srt.contains("00:00:00,500 --> 00:00:02,000"))
        XCTAssertTrue(srt.contains("00:01:02,250 --> 00:01:04,250"))
        let cues = Subtitles.parse(srt)
        XCTAssertEqual(cues.count, 2)
        XCTAssertEqual(cues[1].start, 62.25, accuracy: 1e-6)
        XCTAssertEqual(cues[0].text, "Hello there")
    }

    func testSRTParserToleratesCRLFAndDots() {
        let text = "1\r\n00:00:01.000 --> 00:00:02.500\r\nHi\r\nthere\r\n\r\nbroken block\r\n\r\n2\r\n00:00:03,000 --> 00:00:04,000\r\nOk\r\n"
        let cues = Subtitles.parse(text)
        XCTAssertEqual(cues.count, 2)
        XCTAssertEqual(cues[0].text, "Hi\nthere")
        XCTAssertEqual(cues[0].end, 2.5, accuracy: 1e-6)
    }
}

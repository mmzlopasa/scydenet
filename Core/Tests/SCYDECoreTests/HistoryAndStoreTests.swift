import XCTest
@testable import SCYDECore

final class HistoryAndStoreTests: XCTestCase {

    func testUndoRedoRestoresExactState() {
        var h = History(Project(name: "H", now: Date(timeIntervalSince1970: 1_700_000_000)))
        var id = UUID()
        h.perform("Add") { p in
            id = p.addClip(Clip(kind: .video, name: "A", sourceDuration: 10, duration: 5), role: .main)
            return true
        }
        let afterAdd = h.present
        h.perform("Split") { p in p.split(id, at: 2) != nil }
        XCTAssertEqual(h.present.clipCount, 2)

        h.undo()
        XCTAssertEqual(h.present, afterAdd)
        XCTAssertTrue(h.canRedo)

        h.redo()
        XCTAssertEqual(h.present.clipCount, 2)
        XCTAssertFalse(h.canRedo)
    }

    func testNoOpDoesNotCreateUndoStep() {
        var h = History(Project())
        XCTAssertFalse(h.perform("Nothing") { _ in false })
        XCTAssertFalse(h.canUndo)
    }

    func testNewEditClearsRedo() {
        var h = History(Project())
        h.perform("A") { p in p.name = "A"; return true }
        h.undo()
        XCTAssertTrue(h.canRedo)
        h.perform("B") { p in p.name = "B"; return true }
        XCTAssertFalse(h.canRedo)
    }

    func testTransactionIsASingleUndoStep() {
        var p = Project()
        let id = p.addClip(Clip(kind: .video, name: "A", sourceDuration: 10, duration: 6), role: .main)
        var h = History(p)
        h.beginTransaction()
        for t in stride(from: 5.0, through: 2.0, by: -0.5) {
            h.revise { $0.trim(id, edge: .trailing, to: t) }
        }
        h.commitTransaction("Trim")
        XCTAssertEqual(h.present.clip(id)!.duration, 2, accuracy: 1e-9)
        h.undo()
        XCTAssertEqual(h.present.clip(id)!.duration, 6, accuracy: 1e-9)
        XCTAssertFalse(h.canUndo)
    }

    func testCancelledTransactionRestoresStart() {
        var p = Project()
        let id = p.addClip(Clip(kind: .video, name: "A", sourceDuration: 10, duration: 6), role: .main)
        var h = History(p)
        h.beginTransaction()
        h.revise { $0.trim(id, edge: .trailing, to: 1) }
        h.cancelTransaction()
        XCTAssertEqual(h.present.clip(id)!.duration, 6, accuracy: 1e-9)
        XCTAssertFalse(h.canUndo)
    }

    func testHistoryLimit() {
        var h = History(Project(), limit: 3)
        for i in 0..<10 {
            h.perform("n\(i)") { p in p.name = "n\(i)"; return true }
        }
        var steps = 0
        while h.canUndo { h.undo(); steps += 1 }
        XCTAssertEqual(steps, 3)
    }

    func testStoreRoundTripAndOrdering() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("scyde-test-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = ProjectStore(directory: dir)

        var older = Project(name: "Older", now: Date(timeIntervalSince1970: 1_700_000_000))
        older.addClip(Clip(kind: .photo, name: "P", assetID: "x.jpg", duration: 4), role: .main)
        var newer = Project(name: "Newer", aspect: .landscape16x9, now: Date(timeIntervalSince1970: 1_700_100_000))
        newer.export = ExportSettings(resolution: .p2160, fps: 60, codec: .h264)

        try store.save(older)
        try store.save(newer)

        XCTAssertEqual(try store.load(id: older.id), older)
        XCTAssertEqual(try store.load(id: newer.id), newer)
        XCTAssertEqual(store.list().map { $0.name }, ["Newer", "Older"])

        try store.delete(id: older.id)
        XCTAssertEqual(store.list().count, 1)
    }

    func testListSkipsCorruptFiles() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("scyde-test-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = ProjectStore(directory: dir)
        try store.save(Project(name: "Good"))
        try Data("not json".utf8).write(to: dir.appendingPathComponent("bad.scyde.json"))
        XCTAssertEqual(store.list().map { $0.name }, ["Good"])
    }
}

final class TimecodeAndExportTests: XCTestCase {

    func testTimecodeFormatting() {
        XCTAssertEqual(Timecode.string(0), "0:00.00")
        XCTAssertEqual(Timecode.string(3.4, fps: 30), "0:03.12")
        XCTAssertEqual(Timecode.string(65.5, fps: 30), "1:05.15")
        XCTAssertEqual(Timecode.string(-4), "0:00.00")
        XCTAssertEqual(Timecode.short(65), "1:05")
        XCTAssertEqual(Timecode.duration(4.2), "4.2s")
        XCTAssertEqual(Timecode.duration(75), "1:15")
    }

    func testTimecodeNeverShowsFrameEqualToFps() {
        XCTAssertEqual(Timecode.string(1.99999, fps: 30), "0:01.29")
    }

    func testPixelSizeKeepsShortSideAtResolution() {
        let s = ExportSettings(resolution: .p1080)
        XCTAssertEqual(s.pixelSize(for: .portrait9x16).width, 1080)
        XCTAssertEqual(s.pixelSize(for: .portrait9x16).height, 1920)
        XCTAssertEqual(s.pixelSize(for: .landscape16x9).width, 1920)
        XCTAssertEqual(s.pixelSize(for: .landscape16x9).height, 1080)
        XCTAssertEqual(s.pixelSize(for: .square1x1).width, 1080)
    }

    func testPixelSizeIsAlwaysEven() {
        for aspect in CanvasAspect.allCases {
            for res in ExportSettings.Resolution.allCases {
                let size = ExportSettings(resolution: res).pixelSize(for: aspect)
                XCTAssertEqual(size.width % 2, 0)
                XCTAssertEqual(size.height % 2, 0)
            }
        }
    }

    func testEstimatedSizeScalesWithDurationAndCodec() {
        let h264 = ExportSettings(resolution: .p1080, fps: 30, codec: .h264)
        let hevc = ExportSettings(resolution: .p1080, fps: 30, codec: .hevc)
        let a = h264.estimatedBytes(duration: 10, aspect: .landscape16x9)
        let b = h264.estimatedBytes(duration: 20, aspect: .landscape16x9)
        XCTAssertEqual(Double(b) / Double(a), 2, accuracy: 0.01)
        XCTAssertLessThan(hevc.estimatedBytes(duration: 10, aspect: .landscape16x9), a)
        XCTAssertEqual(h264.estimatedBytes(duration: 0, aspect: .portrait9x16), 0)
    }
}

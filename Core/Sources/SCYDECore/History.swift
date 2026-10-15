import Foundation

/// Snapshot-based undo/redo. Value semantics make every edit trivially reversible.
///
/// Discrete edits use `perform`. Continuous gestures (dragging a trim handle) use
/// `beginTransaction` / `revise` / `commitTransaction` so one drag is one undo step.
public struct History<State: Equatable & Sendable>: Sendable {
    private struct Entry: Sendable {
        var name: String
        var state: State
    }

    public private(set) var present: State
    private var past: [Entry] = []
    private var future: [Entry] = []
    private var transactionStart: State?
    public let limit: Int

    public init(_ initial: State, limit: Int = 200) {
        self.present = initial
        self.limit = limit
    }

    public var canUndo: Bool { !past.isEmpty }
    public var canRedo: Bool { !future.isEmpty }
    public var undoName: String? { past.last?.name }
    public var redoName: String? { future.last?.name }
    public var inTransaction: Bool { transactionStart != nil }

    /// Applies `change`; records an undo step only if it returns true.
    @discardableResult
    public mutating func perform(_ name: String, _ change: (inout State) -> Bool) -> Bool {
        var next = present
        guard change(&next) else { return false }
        push(name, previous: present)
        present = next
        return true
    }

    public mutating func undo() {
        guard let entry = past.popLast() else { return }
        future.append(Entry(name: entry.name, state: present))
        present = entry.state
    }

    public mutating func redo() {
        guard let entry = future.popLast() else { return }
        past.append(Entry(name: entry.name, state: present))
        present = entry.state
    }

    // MARK: Transactions

    public mutating func beginTransaction() {
        transactionStart = present
    }

    /// Recomputes `present` from the transaction's starting state.
    public mutating func revise(_ change: (inout State) -> Void) {
        guard let start = transactionStart else { return }
        var next = start
        change(&next)
        present = next
    }

    public mutating func commitTransaction(_ name: String) {
        guard let start = transactionStart else { return }
        transactionStart = nil
        if present != start {
            push(name, previous: start)
        }
    }

    public mutating func cancelTransaction() {
        guard let start = transactionStart else { return }
        transactionStart = nil
        present = start
    }

    /// Replaces the present state without touching history (e.g. renaming metadata).
    public mutating func replacePresent(_ state: State) {
        present = state
    }

    private mutating func push(_ name: String, previous: State) {
        past.append(Entry(name: name, state: previous))
        if past.count > limit { past.removeFirst(past.count - limit) }
        future.removeAll()
    }
}

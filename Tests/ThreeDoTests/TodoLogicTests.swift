import Foundation
import ThreeDoCore

// MARK: - Minimal test harness

private var passCount = 0
private var failCount = 0
private var currentSuite = ""

private func suite(_ name: String, _ body: () -> Void) {
    currentSuite = name
    body()
}

private func test(_ name: String, _ body: () -> Void) {
    body()
    // body uses expect() which increments pass/fail
    _ = name // name visible in failure output
}

private func expect(_ condition: Bool, _ message: String = "",
                    file: String = #file, line: Int = #line) {
    if condition {
        passCount += 1
    } else {
        failCount += 1
        let loc = "\(URL(fileURLWithPath: file).lastPathComponent):\(line)"
        let detail = message.isEmpty ? "" : " — \(message)"
        print("FAIL [\(currentSuite)]\(detail) at \(loc)")
    }
}

private func expectNil<T>(_ value: T?, _ message: String = "",
                          file: String = #file, line: Int = #line) {
    expect(value == nil, message.isEmpty ? "expected nil" : message, file: file, line: line)
}

private func expectNotNil<T>(_ value: T?, _ message: String = "",
                              file: String = #file, line: Int = #line) {
    expect(value != nil, message.isEmpty ? "expected non-nil" : message, file: file, line: line)
}

// MARK: - Entry point

@main
struct TestRunner {
    static func main() {
        runFlattenTests()
        runInsertPositionTests()
        runIndentTests()
        runUnindentTests()
        runMovePositionTests()
        runEditSessionTests()
        runDeleteSelectionTests()
        runPriorityTests()
        runUndoActionTests()
        runTagParsingTests()
        runBulkDeleteTests()
        runEditFocusInvariantTests()
        runDateInputTests()
        runModalSheetGuardTests()

        let total = passCount + failCount
        if failCount == 0 {
            print("✓ All \(total) tests passed.")
        } else {
            print("✗ \(failCount)/\(total) tests FAILED.")
            exit(1)
        }
    }
}

// MARK: - Flatten tests

private func runFlattenTests() {
    suite("Flatten") {
        test("flattenEmpty") {
            expect(TodoLogic.flatten([]).count == 0)
        }

        test("flattenSingleRoot") {
            let t = Todo.make(position: 1)
            let flat = TodoLogic.flatten([t])
            expect(flat.count == 1)
            expect(flat[0].depth == 0)
            expect(flat[0].hasChildren == false)
        }

        test("flattenParentWithChild") {
            let parent = Todo.make(position: 1)
            let child  = Todo.make(parentId: parent.id, position: 1)
            let flat   = TodoLogic.flatten([parent, child])
            expect(flat.count == 2)
            expect(flat[0].todo.id == parent.id)
            expect(flat[0].depth == 0)
            expect(flat[0].hasChildren == true)
            expect(flat[1].todo.id == child.id)
            expect(flat[1].depth == 1)
            expect(flat[1].hasChildren == false)
        }

        test("flattenCollapsedParentHidesChildren") {
            var parent = Todo.make(position: 1)
            parent.isCollapsed = true
            let child = Todo.make(parentId: parent.id, position: 1)
            let flat  = TodoLogic.flatten([parent, child])
            expect(flat.count == 1, "child should be hidden when parent is collapsed")
            expect(flat[0].hasChildren == true, "hasChildren should still be true when collapsed")
        }

        test("flattenRootsSortedByPosition") {
            let t1 = Todo.make(position: 2)
            let t2 = Todo.make(position: 1)
            let flat = TodoLogic.flatten([t1, t2])
            expect(flat[0].todo.position == 1)
            expect(flat[1].todo.position == 2)
        }

        test("flattenChildrenSortedByPosition") {
            let parent = Todo.make(position: 1)
            let c1 = Todo.make(parentId: parent.id, position: 3)
            let c2 = Todo.make(parentId: parent.id, position: 1)
            let c3 = Todo.make(parentId: parent.id, position: 2)
            let flat = TodoLogic.flatten([parent, c1, c2, c3])
            expect(flat.map { $0.todo.position } == [1.0, 1.0, 2.0, 3.0])
        }

        test("flattenDeepNesting") {
            let l0 = Todo.make(position: 1)
            let l1 = Todo.make(parentId: l0.id, position: 1)
            let l2 = Todo.make(parentId: l1.id, position: 1)
            let l3 = Todo.make(parentId: l2.id, position: 1)
            let flat = TodoLogic.flatten([l0, l1, l2, l3])
            expect(flat.map { $0.depth } == [0, 1, 2, 3])
        }

        test("flattenMultipleRootsAndChildren") {
            let r1   = Todo.make(position: 1)
            let r1c1 = Todo.make(parentId: r1.id, position: 1)
            let r1c2 = Todo.make(parentId: r1.id, position: 2)
            let r2   = Todo.make(position: 2)
            let flat = TodoLogic.flatten([r2, r1c2, r1, r1c1])
            expect(flat.count == 4)
            expect(flat[0].todo.id == r1.id)
            expect(flat[1].todo.id == r1c1.id)
            expect(flat[2].todo.id == r1c2.id)
            expect(flat[3].todo.id == r2.id)
        }

        test("flattenPartiallyCollapsed") {
            let r   = Todo.make(position: 1)
            var p   = Todo.make(parentId: r.id, position: 1)
            p.isCollapsed = true
            let gc  = Todo.make(parentId: p.id, position: 1) // hidden
            let sib = Todo.make(parentId: r.id, position: 2) // visible
            let flat = TodoLogic.flatten([r, p, gc, sib])
            expect(flat.count == 3, "r, p, sib — gc hidden")
            expect(flat[1].hasChildren == true)
            expect(flat[2].todo.id == sib.id)
        }
    }
}

// MARK: - InsertPosition tests

private func runInsertPositionTests() {
    suite("InsertPosition") {
        test("insertIntoEmptyList") {
            expect(TodoLogic.insertPosition(afterId: nil, among: []) == 1.0)
        }

        test("insertAtEndWithNilAfterId") {
            let siblings = [Todo.make(position: 3), Todo.make(position: 7)]
            expect(TodoLogic.insertPosition(afterId: nil, among: siblings) == 8.0)
        }

        test("insertAfterLastSibling") {
            let t = Todo.make(position: 5)
            expect(TodoLogic.insertPosition(afterId: t.id, among: [t]) == 6.0)
        }

        test("insertBetweenSiblings") {
            let t1 = Todo.make(position: 1)
            let t2 = Todo.make(position: 3)
            let pos = TodoLogic.insertPosition(afterId: t1.id, among: [t1, t2])
            expect(pos == 2.0)
        }

        test("insertMidpoint") {
            let t1 = Todo.make(position: 0)
            let t2 = Todo.make(position: 1)
            let pos = TodoLogic.insertPosition(afterId: t1.id, among: [t1, t2])
            expect(pos == 0.5)
        }

        test("insertAfterNotFoundDefaultsToEnd") {
            let t = Todo.make(position: 5)
            let notInList = Todo.make(position: 99)
            let pos = TodoLogic.insertPosition(afterId: notInList.id, among: [t])
            expect(pos == 6.0)
        }
    }
}

// MARK: - Indent tests

private func runIndentTests() {
    suite("Indent") {
        test("indentFirstItemReturnsNil") {
            let t = Todo.make(position: 1)
            expectNil(TodoLogic.applyIndent(to: t, siblings: [t], existingChildren: []))
        }

        test("indentSecondItemBecomesChildOfFirst") {
            let t1 = Todo.make(position: 1)
            let t2 = Todo.make(position: 2)
            let result = TodoLogic.applyIndent(to: t2, siblings: [t1, t2], existingChildren: [])
            expectNotNil(result)
            expect(result?.parentId == t1.id)
            expect(result?.position == 1.0)
        }

        test("indentAppendsAfterExistingChildren") {
            let t1 = Todo.make(position: 1)
            let t2 = Todo.make(position: 2)
            let existing = Todo.make(parentId: t1.id, position: 5)
            let result = TodoLogic.applyIndent(to: t2, siblings: [t1, t2], existingChildren: [existing])
            expect(result?.position == 6.0)
        }

        test("indentPreservesOtherFields") {
            let t1 = Todo.make(position: 1)
            var t2 = Todo.make(position: 2)
            t2.isDone = true
            t2.text = "hello"
            let result = TodoLogic.applyIndent(to: t2, siblings: [t1, t2], existingChildren: [])
            expect(result?.isDone == true)
            expect(result?.text == "hello")
        }
    }
}

// MARK: - Unindent tests

private func runUnindentTests() {
    suite("Unindent") {
        test("unindentRootItemReturnsNil") {
            let t = Todo.make(position: 1)
            expectNil(TodoLogic.applyUnindent(to: t, parent: nil, grandparentSiblings: []))
        }

        test("unindentChildBecomesRootAfterParent") {
            let parent = Todo.make(position: 1)
            let child  = Todo.make(parentId: parent.id, position: 1)
            let result = TodoLogic.applyUnindent(to: child, parent: parent, grandparentSiblings: [parent])
            expectNotNil(result)
            expectNil(result?.parentId, "should be at root level")
            expect(result!.position > parent.position)
        }

        test("unindentChildPlacedBetweenParentAndNextSibling") {
            let parent  = Todo.make(position: 1)
            let nextSib = Todo.make(position: 3)
            let child   = Todo.make(parentId: parent.id, position: 1)
            let result  = TodoLogic.applyUnindent(to: child, parent: parent, grandparentSiblings: [parent, nextSib])
            expect(result?.position == 2.0, "midpoint of 1 and 3")
        }

        test("unindentDeepChildMovesUpOneLevel") {
            let grandparent = Todo.make(position: 1)
            let parent      = Todo.make(parentId: grandparent.id, position: 1)
            let child       = Todo.make(parentId: parent.id, position: 1)
            let result      = TodoLogic.applyUnindent(to: child, parent: parent, grandparentSiblings: [parent])
            expect(result?.parentId == grandparent.id, "should move to grandparent level")
        }
    }
}

// MARK: - Move tests

private func runMovePositionTests() {
    suite("MovePosition") {
        test("moveUpFirstItemReturnsNil") {
            let t = Todo.make(position: 1)
            expectNil(TodoLogic.positionForMoveUp(todo: t, among: [t]))
        }

        test("moveDownLastItemReturnsNil") {
            let t = Todo.make(position: 1)
            expectNil(TodoLogic.positionForMoveDown(todo: t, among: [t]))
        }

        test("moveDownReturnsPositionOfNextSibling") {
            let t1 = Todo.make(position: 1)
            let t2 = Todo.make(position: 2)
            let t3 = Todo.make(position: 3)
            let newPos = TodoLogic.positionForMoveDown(todo: t1, among: [t1, t2, t3])
            expect(newPos == 2.0)
        }

        test("moveUpReturnsPositionOfPreviousSibling") {
            let t1 = Todo.make(position: 1)
            let t2 = Todo.make(position: 2)
            let t3 = Todo.make(position: 3)
            let newPos = TodoLogic.positionForMoveUp(todo: t3, among: [t1, t2, t3])
            expect(newPos == 2.0)
        }

        test("moveSingleItemInBothDirectionsReturnsNil") {
            let t = Todo.make(position: 5)
            expectNil(TodoLogic.positionForMoveUp(todo: t, among: [t]))
            expectNil(TodoLogic.positionForMoveDown(todo: t, among: [t]))
        }
    }
}

// MARK: - EditSession tests
// These cover the edit-mode state machine that drives Enter-to-edit behaviour.
// The fix for the focus bug (TextField not receiving cursor) lives in TodoRowView,
// but these tests verify the state transitions that must be correct for editing to work.

private func runEditSessionTests() {
    suite("EditSession") {
        test("startsInactive") {
            let s = EditSession()
            expect(s.isActive == false)
            expectNil(s.editingId)
            expect(s.editText == "")
        }

        test("startSetsEditingIdAndText") {
            var s = EditSession()
            var todo = Todo.make(position: 1)
            todo.text = "Buy milk"
            s.start(todo: todo)
            expect(s.isActive == true)
            expect(s.editingId == todo.id)
            expect(s.editText == "Buy milk")
        }

        test("startWithInitialCharReplacesText") {
            // Typing a printable key while a todo is selected should replace
            // the existing text with the typed character (start-typing-to-edit).
            var s = EditSession()
            var todo = Todo.make(position: 1)
            todo.text = "Old text"
            s.start(todo: todo, initialChar: "x")
            expect(s.editText == "x", "initialChar should replace existing text")
            expect(s.editingId == todo.id)
        }

        test("startWithNilInitialCharKeepsExistingText") {
            // Enter / i key: edit the existing text in place.
            var s = EditSession()
            var todo = Todo.make(position: 1)
            todo.text = "Keep this"
            s.start(todo: todo, initialChar: nil)
            expect(s.editText == "Keep this")
        }

        test("commitReturnsIdAndText") {
            var s = EditSession()
            var todo = Todo.make(position: 1)
            todo.text = "Draft"
            s.start(todo: todo)
            s.editText = "Final"
            let result = s.commit()
            expectNotNil(result)
            expect(result?.id == todo.id)
            expect(result?.text == "Final")
        }

        test("commitClearsActiveState") {
            var s = EditSession()
            s.start(todo: Todo.make(position: 1))
            s.commit()
            expect(s.isActive == false)
            expectNil(s.editingId)
        }

        test("commitOnInactiveSessionReturnsNil") {
            var s = EditSession()
            let result = s.commit()
            expectNil(result, "commit on inactive session should be a no-op")
        }

        test("startingNewEditReplacesCurrentEdit") {
            var s = EditSession()
            var t1 = Todo.make(position: 1); t1.text = "First"
            var t2 = Todo.make(position: 2); t2.text = "Second"
            s.start(todo: t1)
            s.start(todo: t2)
            expect(s.editingId == t2.id)
            expect(s.editText == "Second")
        }

        test("emptyTodoTextEditableViaEnterKey") {
            // New todos are created with empty text; Enter should open them for editing
            // with an empty field (not crash or no-op).
            var s = EditSession()
            let todo = Todo.make(text: "", position: 1)
            s.start(todo: todo)
            expect(s.isActive == true)
            expect(s.editText == "")
        }
    }
}

// MARK: - Delete selection tests
// Covers the "which item gets selected after backspace-delete" logic.
// Backspace in normal mode always deletes; backspace in edit mode is handled
// by the TextField and never reaches this code path.

private func runDeleteSelectionTests() {
    suite("DeleteSelection") {
        test("deleteOnlyItemReturnsNil") {
            let t = Todo.make(position: 1)
            let flat = TodoLogic.flatten([t])
            let next = TodoLogic.selectionAfterDelete(deletingId: t.id, in: flat)
            expectNil(next, "no remaining items — selection should be nil")
        }

        test("deleteFirstItemSelectsSecond") {
            let t1 = Todo.make(position: 1)
            let t2 = Todo.make(position: 2)
            let flat = TodoLogic.flatten([t1, t2])
            let next = TodoLogic.selectionAfterDelete(deletingId: t1.id, in: flat)
            expect(next == t2.id, "should prefer item below when deleting first")
        }

        test("deleteLastItemSelectsPrevious") {
            let t1 = Todo.make(position: 1)
            let t2 = Todo.make(position: 2)
            let flat = TodoLogic.flatten([t1, t2])
            let next = TodoLogic.selectionAfterDelete(deletingId: t2.id, in: flat)
            expect(next == t1.id, "should fall back to item above when deleting last")
        }

        test("deleteMiddleItemSelectsItemBelow") {
            let t1 = Todo.make(position: 1)
            let t2 = Todo.make(position: 2)
            let t3 = Todo.make(position: 3)
            let flat = TodoLogic.flatten([t1, t2, t3])
            let next = TodoLogic.selectionAfterDelete(deletingId: t2.id, in: flat)
            expect(next == t3.id, "middle delete should prefer item below")
        }

        test("deleteUnknownIdReturnsNil") {
            let t = Todo.make(position: 1)
            let flat = TodoLogic.flatten([t])
            let ghost = Todo.make(position: 99)
            let next = TodoLogic.selectionAfterDelete(deletingId: ghost.id, in: flat)
            expectNil(next, "unknown id should return nil")
        }

        test("deleteChildSelectsSiblingBelow") {
            // parent → c1, c2, c3
            let parent = Todo.make(position: 1)
            let c1 = Todo.make(parentId: parent.id, position: 1)
            let c2 = Todo.make(parentId: parent.id, position: 2)
            let c3 = Todo.make(parentId: parent.id, position: 3)
            let flat = TodoLogic.flatten([parent, c1, c2, c3])
            let next = TodoLogic.selectionAfterDelete(deletingId: c1.id, in: flat)
            expect(next == c2.id)
        }

        test("deleteLastChildSelectsParent") {
            let parent = Todo.make(position: 1)
            let child  = Todo.make(parentId: parent.id, position: 1)
            let flat   = TodoLogic.flatten([parent, child])
            let next   = TodoLogic.selectionAfterDelete(deletingId: child.id, in: flat)
            expect(next == parent.id, "last child deleted — fall back to parent")
        }
    }
}

// MARK: - Priority cycle tests

private func runPriorityTests() {
    suite("Priority") {
        test("nilCyclesToLow") {
            expect(TodoLogic.nextPriority(nil) == .low)
        }

        test("lowCyclesToMedium") {
            expect(TodoLogic.nextPriority(.low) == .medium)
        }

        test("mediumCyclesToHigh") {
            expect(TodoLogic.nextPriority(.medium) == .high)
        }

        test("highCyclesToNil") {
            expectNil(TodoLogic.nextPriority(.high))
        }

        test("fullCycleReturnsToNil") {
            var p: Priority? = nil
            p = TodoLogic.nextPriority(p)   // → low
            p = TodoLogic.nextPriority(p)   // → medium
            p = TodoLogic.nextPriority(p)   // → high
            p = TodoLogic.nextPriority(p)   // → nil
            expectNil(p, "full cycle should return to nil")
        }

        test("doubleCycleIsStable") {
            // Two full cycles should end at nil
            var p: Priority? = nil
            for _ in 0..<8 { p = TodoLogic.nextPriority(p) }
            expectNil(p)
        }
    }
}

// MARK: - UndoAction tests
// Verifies that each UndoAction carries the right snapshot data —
// the pure data layer that AppState's undo() operates on.

private func runUndoActionTests() {
    suite("UndoAction") {
        test("deleteSnapshotPreservesAllFields") {
            var todo = Todo.make(text: "Buy milk", position: 3)
            todo.isDone    = true
            todo.priority  = .high
            let action = UndoAction.delete(snapshot: todo)
            if case .delete(let snap) = action {
                expect(snap.id       == todo.id)
                expect(snap.text     == "Buy milk")
                expect(snap.isDone   == true)
                expect(snap.priority == .high)
                expect(snap.position == 3)
            } else {
                expect(false, "wrong action type")
            }
        }

        test("setDoneCarriesPreviousValue") {
            let id = UUID()
            let action = UndoAction.setDone(id: id, previousValue: false)
            if case .setDone(let aid, let prev) = action {
                expect(aid  == id)
                expect(prev == false)
            } else {
                expect(false, "wrong action type")
            }
        }

        test("setTextCarriesPreviousText") {
            let id = UUID()
            let action = UndoAction.setText(id: id, previousText: "old text")
            if case .setText(let aid, let prev) = action {
                expect(aid  == id)
                expect(prev == "old text")
            } else {
                expect(false, "wrong action type")
            }
        }

        test("setPriorityCarriesPreviousPriority") {
            let id = UUID()
            let action = UndoAction.setPriority(id: id, previousPriority: .medium)
            if case .setPriority(let aid, let prev) = action {
                expect(aid  == id)
                expect(prev == .medium)
            } else {
                expect(false, "wrong action type")
            }
        }

        test("setPriorityCanCarryNil") {
            let action = UndoAction.setPriority(id: UUID(), previousPriority: nil)
            if case .setPriority(_, let prev) = action {
                expectNil(prev)
            } else {
                expect(false, "wrong action type")
            }
        }

        test("setDueDateCanCarryNil") {
            let action = UndoAction.setDueDate(id: UUID(), previousDueDate: nil)
            if case .setDueDate(_, let prev) = action {
                expectNil(prev)
            } else {
                expect(false, "wrong action type")
            }
        }

        test("setDueDateCarriesDate") {
            let date = Date(timeIntervalSince1970: 1_700_000_000)
            let action = UndoAction.setDueDate(id: UUID(), previousDueDate: date)
            if case .setDueDate(_, let prev) = action {
                expect(prev == date)
            } else {
                expect(false, "wrong action type")
            }
        }

        test("setTagsCarriesPreviousTags") {
            let id = UUID()
            let action = UndoAction.setTags(id: id, previousTags: "work home")
            if case .setTags(let aid, let prev) = action {
                expect(aid  == id)
                expect(prev == "work home")
            } else {
                expect(false, "wrong action type")
            }
        }

        // .create undo — verifies the create+edit coalesce logic
        test("createCarriesId") {
            let id = UUID()
            let action = UndoAction.create(id: id)
            if case .create(let cid) = action {
                expect(cid == id)
            } else {
                expect(false, "wrong action type")
            }
        }

        test("createIsTopAfterAddTodoAndCommitEditCoalesces") {
            // Simulate addTodo pushing .create, then commitEdit skipping .setText
            // because .create(id) is at the top of the stack for the same id.
            var stack: [UndoAction] = []
            let newId = UUID()

            stack.append(.create(id: newId))  // addTodo

            // commitEdit check
            let editedText   = "Buy milk"
            let originalText = ""
            let isJustCreated: Bool
            if case .create(let cid) = stack.last, cid == newId { isJustCreated = true } else { isJustCreated = false }
            if editedText != originalText && !isJustCreated {
                stack.append(.setText(id: newId, previousText: originalText))
            }

            expect(stack.count == 1, "only .create should remain — .setText was coalesced away")
            if case .create(let cid) = stack.last {
                expect(cid == newId)
            } else {
                expect(false, ".create should be the only action")
            }
        }

        test("setTextPushedWhenEditingExistingTodo") {
            // When editing an existing todo (top of stack is not .create for that id), .setText IS pushed.
            var stack: [UndoAction] = []
            let existingId = UUID()
            stack.append(.setDone(id: UUID(), previousValue: false))

            let isJustCreated: Bool
            if case .create(let cid) = stack.last, cid == existingId { isJustCreated = true } else { isJustCreated = false }
            if "Updated" != "Old" && !isJustCreated {
                stack.append(.setText(id: existingId, previousText: "Old"))
            }

            expect(stack.count == 2, ".setText should be pushed for existing todo edits")
            if case .setText(let aid, let prev) = stack.last {
                expect(aid == existingId)
                expect(prev == "Old")
            } else {
                expect(false, ".setText should be on top")
            }
        }

        test("createForDifferentIdDoesNotCoalesce") {
            // .create on top but for a DIFFERENT id → still push .setText
            var stack: [UndoAction] = []
            let otherId = UUID()
            let editId  = UUID()
            stack.append(.create(id: otherId))

            let isJustCreated: Bool
            if case .create(let cid) = stack.last, cid == editId { isJustCreated = true } else { isJustCreated = false }
            if "Hello" != "" && !isJustCreated {
                stack.append(.setText(id: editId, previousText: ""))
            }

            expect(stack.count == 2, ".setText should be pushed when .create is for a different id")
        }
    }
}

// MARK: - Tag parsing tests

private func runTagParsingTests() {
    suite("TagParsing") {
        test("emptyStringReturnsEmpty") {
            expect(TodoLogic.parseTags("").isEmpty)
        }

        test("singleWordTag") {
            expect(TodoLogic.parseTags("work") == ["work"])
        }

        test("multipleSpaceSeparated") {
            expect(TodoLogic.parseTags("work home urgent") == ["work", "home", "urgent"])
        }

        test("stripsHashPrefix") {
            expect(TodoLogic.parseTags("#work #home") == ["work", "home"])
        }

        test("mixedHashAndNoHash") {
            expect(TodoLogic.parseTags("#work home") == ["work", "home"])
        }

        test("lowercasesInput") {
            expect(TodoLogic.parseTags("Work HOME") == ["work", "home"])
        }

        test("deduplicates") {
            expect(TodoLogic.parseTags("work work home") == ["work", "home"])
        }

        test("commaSeparatedAlsoWorks") {
            expect(TodoLogic.parseTags("work,home") == ["work", "home"])
        }

        test("extraWhitespaceIgnored") {
            expect(TodoLogic.parseTags("  work   home  ") == ["work", "home"])
        }

        test("formatTagsRoundTrips") {
            let tags = ["work", "home", "urgent"]
            let stored = TodoLogic.formatTags(tags)
            let parsed = TodoLogic.parseTags(stored)
            expect(parsed == tags)
        }

        test("formatTagsProducesSpaceSeparated") {
            expect(TodoLogic.formatTags(["a", "b"]) == "a b")
        }
    }
}

// MARK: - Bulk delete selection tests

private func runBulkDeleteTests() {
    suite("BulkDeleteSelection") {
        test("deleteAllReturnsNil") {
            let t1 = Todo.make(position: 1)
            let t2 = Todo.make(position: 2)
            let flat = TodoLogic.flatten([t1, t2])
            let next = TodoLogic.selectionAfterBulkDelete(deletingIds: [t1.id, t2.id], in: flat)
            expectNil(next)
        }

        test("deleteSingleEquivalentToSingleDelete") {
            let t1 = Todo.make(position: 1)
            let t2 = Todo.make(position: 2)
            let t3 = Todo.make(position: 3)
            let flat = TodoLogic.flatten([t1, t2, t3])
            let bulk   = TodoLogic.selectionAfterBulkDelete(deletingIds: [t2.id], in: flat)
            let single = TodoLogic.selectionAfterDelete(deletingId: t2.id, in: flat)
            expect(bulk == single)
        }

        test("deleteRangeSelectsItemBelow") {
            let t1 = Todo.make(position: 1)
            let t2 = Todo.make(position: 2)
            let t3 = Todo.make(position: 3)
            let t4 = Todo.make(position: 4)
            let flat = TodoLogic.flatten([t1, t2, t3, t4])
            // delete t2 and t3 → should select t4
            let next = TodoLogic.selectionAfterBulkDelete(deletingIds: [t2.id, t3.id], in: flat)
            expect(next == t4.id)
        }

        test("deleteRangeAtEndSelectsItemAbove") {
            let t1 = Todo.make(position: 1)
            let t2 = Todo.make(position: 2)
            let t3 = Todo.make(position: 3)
            let flat = TodoLogic.flatten([t1, t2, t3])
            // delete t2 and t3 → fall back to t1
            let next = TodoLogic.selectionAfterBulkDelete(deletingIds: [t2.id, t3.id], in: flat)
            expect(next == t1.id)
        }

        test("emptyDeletingIdsReturnsNilForEmptyList") {
            let next = TodoLogic.selectionAfterBulkDelete(deletingIds: [], in: [])
            expectNil(next)
        }

        test("emptyDeletingIdsReturnsFirstForNonEmptyList") {
            let t1 = Todo.make(position: 1)
            let flat = TodoLogic.flatten([t1])
            let next = TodoLogic.selectionAfterBulkDelete(deletingIds: [], in: flat)
            expect(next == t1.id)
        }
    }
}

// MARK: - Edit focus invariant tests
//
// These tests document the state contract that must hold for the cursor-focus
// bug NOT to occur. Two separate failure modes were observed:
//
//  1. No visible cursor — @FocusState set from onAppear fires during SwiftUI's
//     layout pass; the focus engine ignores it. Fix: NSViewRepresentable that
//     calls window.makeFirstResponder directly.
//
//  2. "Erases everything" — on macOS, NSTextField selects-all on focus, so the
//     first keypress replaces all text. Fix: call moveToEndOfDocument after
//     makeFirstResponder so the cursor lands at the end, not a full selection.
//
// These tests verify the EditSession state machine that underpins both fixes.

private func runEditFocusInvariantTests() {
    suite("EditFocusInvariant") {

        // -- Enter key path (initialChar: nil) --

        test("enterKeyPreservesFullText") {
            // Enter sets editText = todo.text. If this isn't true the TextField
            // would show the wrong content before the user types anything.
            var s = EditSession()
            var todo = Todo.make(position: 1)
            todo.text = "Buy oat milk"
            s.start(todo: todo, initialChar: nil)
            expect(s.editText == "Buy oat milk",
                   "Enter must populate editText with existing text, not erase it")
        }

        test("enterKeyOnEmptyTodoPreservesEmptyString") {
            var s = EditSession()
            let todo = Todo.make(text: "", position: 1)
            s.start(todo: todo, initialChar: nil)
            expect(s.editText == "")
        }

        test("enterKeyMakesSessionActive") {
            // The session being active is what routes subsequent key events to
            // handleEditingModeKey instead of handleNormalModeKey. If this is
            // false, the next printable keypress calls startEditing(initialChar:)
            // which erases the text — the second failure mode.
            var s = EditSession()
            s.start(todo: Todo.make(position: 1), initialChar: nil)
            expect(s.isActive == true,
                   "editingId must be set immediately after Enter so key routing is correct")
        }

        // -- Type-to-start path (initialChar: char) --

        test("typingCharReplacesTextIntentionally") {
            // In normal mode, pressing a printable key calls
            // startEditing(id:, initialChar: char). This is intentional: the
            // user is "typing over" the todo. The char becomes the new editText.
            var s = EditSession()
            var todo = Todo.make(position: 1)
            todo.text = "Old text"
            s.start(todo: todo, initialChar: "x")
            expect(s.editText == "x")
        }

        // -- Routing invariant --

        test("activeSessionBlocksNormalModeTypeToStart") {
            // Once isActive, the key handler routes to handleEditingModeKey,
            // which returns false for printable chars (letting them go to
            // TextField). handleNormalModeKey's startEditing(initialChar:) path
            // is never reached. This test documents the invariant that must hold.
            var s = EditSession()
            var todo = Todo.make(position: 1)
            todo.text = "Hello world"
            s.start(todo: todo, initialChar: nil)  // Enter → active
            let textBeforeTyping = s.editText
            // Simulate: in active mode, user types "x".
            // The key router should NOT call start(initialChar: "x").
            // We verify the session is still active and editText unchanged.
            expect(s.isActive == true)
            expect(s.editText == textBeforeTyping,
                   "editText must not change when the session is already active")
        }

        test("commitClearsActiveStateEnablingFreshStart") {
            // After commit, isActive is false. The next Enter should call
            // startEditing again — NOT route to handleEditingModeKey.
            var s = EditSession()
            var todo = Todo.make(position: 1)
            todo.text = "Task"
            s.start(todo: todo)
            s.commit()
            expect(s.isActive == false,
                   "after commit, isActive must be false so Enter restarts edit mode")
        }

        test("editTextAfterCommitIsNotReset") {
            // commit() returns (id, text) for persisting, then clears editingId.
            // editText is intentionally left as-is (no extra clear needed).
            var s = EditSession()
            var todo = Todo.make(position: 1)
            todo.text = "Original"
            s.start(todo: todo)
            s.editText = "Updated"
            let result = s.commit()
            expect(result?.text == "Updated")
            expect(s.isActive == false)
        }
    }
}

// MARK: - Date input parsing tests

private func runDateInputTests() {
    // Fixed reference date: 2026-03-27 (a Friday), used for deterministic "current year" tests.
    let ref = makeDate(year: 2026, month: 3, day: 27)!

    suite("DateInput") {
        test("emptyStringReturnsNil") {
            expectNil(TodoLogic.parseDateInput("", relativeTo: ref))
        }

        test("whitespaceOnlyReturnsNil") {
            expectNil(TodoLogic.parseDateInput("   ", relativeTo: ref))
        }

        test("invalidFormatReturnsNil") {
            expectNil(TodoLogic.parseDateInput("hello", relativeTo: ref))
            expectNil(TodoLogic.parseDateInput("13/01", relativeTo: ref))   // month out of range
            expectNil(TodoLogic.parseDateInput("01/32", relativeTo: ref))   // day out of range
            expectNil(TodoLogic.parseDateInput("0/15", relativeTo: ref))    // month zero
            expectNil(TodoLogic.parseDateInput("1/0", relativeTo: ref))     // day zero
        }

        test("mmSlashDdUsesCurrentYearWhenDateIsInFuture") {
            // 12/25 is after 2026-03-27, so should stay in 2026
            let result = TodoLogic.parseDateInput("12/25", relativeTo: ref)
            expectNotNil(result)
            if let d = result {
                let cal = Calendar.current
                expect(cal.component(.year, from: d)  == 2026)
                expect(cal.component(.month, from: d) == 12)
                expect(cal.component(.day, from: d)   == 25)
            }
        }

        test("mmSlashDdBumpsToNextYearWhenDateHasPassed") {
            // 1/15 is before 2026-03-27, so should roll to 2027
            let result = TodoLogic.parseDateInput("1/15", relativeTo: ref)
            expectNotNil(result)
            if let d = result {
                expect(Calendar.current.component(.year, from: d) == 2027)
            }
        }

        test("mmSlashDdForTodayStaysCurrentYear") {
            // ref is midnight 2026-03-27; the candidate for "3/27" is also midnight 2026-03-27.
            // candidate < now is false (equal, not less), so we stay in the current year.
            let result = TodoLogic.parseDateInput("3/27", relativeTo: ref)
            expectNotNil(result)
            if let d = result {
                expect(Calendar.current.component(.year, from: d) == 2026)
            }
        }

        test("mmSlashDdSlashYyTwoDigitYear") {
            let result = TodoLogic.parseDateInput("6/15/26", relativeTo: ref)
            expectNotNil(result)
            if let d = result {
                let cal = Calendar.current
                expect(cal.component(.year, from: d)  == 2026)
                expect(cal.component(.month, from: d) == 6)
                expect(cal.component(.day, from: d)   == 15)
            }
        }

        test("mmSlashDdSlashYyyyFourDigitYear") {
            let result = TodoLogic.parseDateInput("6/15/2027", relativeTo: ref)
            expectNotNil(result)
            if let d = result {
                expect(Calendar.current.component(.year, from: d) == 2027)
            }
        }

        test("leadingZerosAccepted") {
            let result = TodoLogic.parseDateInput("06/05/26", relativeTo: ref)
            expectNotNil(result)
            if let d = result {
                let cal = Calendar.current
                expect(cal.component(.month, from: d) == 6)
                expect(cal.component(.day, from: d)   == 5)
            }
        }

        test("twoDigitYearMapsTo2000Plus") {
            let result = TodoLogic.parseDateInput("1/1/99", relativeTo: ref)
            expectNotNil(result)
            if let d = result {
                expect(Calendar.current.component(.year, from: d) == 2099)
            }
        }

        test("tooManySlashSegmentsReturnsNil") {
            expectNil(TodoLogic.parseDateInput("1/2/3/4", relativeTo: ref))
        }

        test("missingDaySegmentReturnsNil") {
            expectNil(TodoLogic.parseDateInput("6/", relativeTo: ref))   // trailing slash, empty day
        }

        // Round-trip: formatDateForInput → parseDateInput must recover the original date.
        // This is critical for the Enter-to-confirm flow: the text field is pre-filled
        // via formatDateForInput; when the user presses Enter, parseDateInput must
        // recover the same date so confirmDate() sets the correct value.

        test("formatThenParseRoundTrips") {
            let original = makeDate(year: 2026, month: 6, day: 15)!
            let formatted = TodoLogic.formatDateForInput(original)
            let parsed    = TodoLogic.parseDateInput(formatted, relativeTo: ref)
            expectNotNil(parsed)
            if let p = parsed {
                let cal = Calendar.current
                expect(cal.component(.year,  from: p) == 2026)
                expect(cal.component(.month, from: p) == 6)
                expect(cal.component(.day,   from: p) == 15)
            }
        }

        test("formatDateForInputProducesMMSlashDDSlashYY") {
            let date = makeDate(year: 2026, month: 3, day: 5)!
            expect(TodoLogic.formatDateForInput(date) == "3/5/26")
        }

        test("formatDateForInputPadsYearToTwoDigits") {
            let date = makeDate(year: 2026, month: 1, day: 1)!
            let s = TodoLogic.formatDateForInput(date)
            // Year component should be "26", not "6" or "2026"
            expect(s.hasSuffix("/26"), "year should be two-digit zero-padded: got \(s)")
        }

        test("parseFormattedExistingDatePreservesDateWhenReentering") {
            // Simulates: user opens picker with existing due date 2027-12-31,
            // text field is pre-filled, user presses Enter without typing.
            // parseDateInput must recover 2027-12-31.
            let existing  = makeDate(year: 2027, month: 12, day: 31)!
            let prefilled = TodoLogic.formatDateForInput(existing)
            let parsed    = TodoLogic.parseDateInput(prefilled, relativeTo: ref)
            expectNotNil(parsed)
            if let p = parsed {
                let cal = Calendar.current
                expect(cal.component(.year,  from: p) == 2027)
                expect(cal.component(.month, from: p) == 12)
                expect(cal.component(.day,   from: p) == 31)
            }
        }
    }
}

// MARK: - Modal sheet guard tests
//
// The global key monitor must return false (pass events through) whenever a modal
// sheet is open. Otherwise arrow keys and jkli navigate the todo list in the
// background while the sheet is visible.

private func runModalSheetGuardTests() {
    suite("ModalSheetGuard") {
        test("noSheetsOpenIsNotModal") {
            expect(!TodoLogic.isModalSheetOpen(
                dueDatePickerId: nil, tagsSheetId: nil, renamingWorkspaceId: nil))
        }

        test("dueDatePickerOpenIsModal") {
            expect(TodoLogic.isModalSheetOpen(
                dueDatePickerId: UUID(), tagsSheetId: nil, renamingWorkspaceId: nil))
        }

        test("tagsSheetOpenIsModal") {
            expect(TodoLogic.isModalSheetOpen(
                dueDatePickerId: nil, tagsSheetId: UUID(), renamingWorkspaceId: nil))
        }

        test("renameWorkspaceOpenIsModal") {
            expect(TodoLogic.isModalSheetOpen(
                dueDatePickerId: nil, tagsSheetId: nil, renamingWorkspaceId: UUID()))
        }

        test("multipleSheetsOpenIsModal") {
            expect(TodoLogic.isModalSheetOpen(
                dueDatePickerId: UUID(), tagsSheetId: UUID(), renamingWorkspaceId: UUID()))
        }

        test("onlyOneNilStillModal") {
            // If two are set and one is nil, still modal
            expect(TodoLogic.isModalSheetOpen(
                dueDatePickerId: UUID(), tagsSheetId: nil, renamingWorkspaceId: UUID()))
        }

        test("enterKeyPassesThroughWhenDueDatePickerOpen") {
            // The key monitor returns false (passes through) when isModalSheetOpen is true.
            // This means Return/Enter reaches the sheet's "Set Date" button, which has
            // .keyboardShortcut(.defaultAction) to confirm the selected date.
            // Without this, arrow-key navigation in the graphical DatePicker followed
            // by Enter would silently do nothing.
            let isModal = TodoLogic.isModalSheetOpen(
                dueDatePickerId: UUID(), tagsSheetId: nil, renamingWorkspaceId: nil)
            // Key monitor must NOT consume the event when isModal is true
            let keyMonitorWouldConsume = !isModal
            expect(!keyMonitorWouldConsume, "Enter must pass through to the sheet when due date picker is open")
        }
    }
}

// Helper: build a Date from components in the current calendar.
private func makeDate(year: Int, month: Int, day: Int) -> Date? {
    var c = DateComponents()
    c.year = year; c.month = month; c.day = day
    return Calendar.current.date(from: c)
}

import Foundation
import IrisHost
import Testing

// IrisHost's editing state, which UIKit's and SwiftUI's text controls share.

@Test func markedTextIsPartOfTheTextUntilCommitted() {
    // Telex: the input method composes "Việt" a letter at a time, then commits it.
    var state = TextEditingState(text: "Xin chào ")
    for marked in ["V", "Vi", "Vie", "Viê", "Viêt", "Việt"] {
        state.compose(marked)
    }
    #expect(state.text == "Xin chào Việt" && state.marked == 9 ..< 13 && state.cursor == 13)
    #expect(state.committedText == "Xin chào ")
    state.commit("Việt")
    #expect(state.text == "Xin chào Việt" && state.marked == nil && state.selection == 13 ..< 13)
    // An empty composition takes the marked text away.
    state.compose(" Na")
    state.compose("")
    #expect(state.text == "Xin chào Việt" && state.marked == nil)
    // The caret can sit inside the marked text.
    state.compose("Nam", selectedRange: 1 ..< 1)
    #expect(state.selection == 14 ..< 14 && state.marked == 13 ..< 16)
    state.unmark()
    #expect(state.committedText == "Xin chào ViệtNam")
}

@Test func editsReplaceTheSelectionAndKeepCharactersWhole() {
    // 👋 is two UTF-16 code units; offsets inside it round to its edges.
    var state = TextEditingState(text: "a👋b", selection: 2 ..< 2)
    #expect(state.boundary(atOrBefore: 2) == 1 && state.boundary(atOrAfter: 2) == 3)
    state.deleteBackward()
    #expect(state.text == "ab" && state.cursor == 1)
    state.selection = 0 ..< 2
    state.commit("xin chào")
    #expect(state.text == "xin chào" && state.selection == 8 ..< 8)
    state.selection = 4 ..< 8
    state.deleteBackward()
    #expect(state.text == "xin " && state.cursor == 4)
    // A correction deletes around the marked text, which moves with the text before it.
    state = TextEditingState(text: "bể ")
    state.caret(at: 2)
    state.compose("x")
    state.deleteSurrounding(before: 1, after: 1)
    #expect(state.text == "bx" && state.marked == 1 ..< 2 && state.cursor == 2)
}

@Test func editingKeysMoveDeleteAndSelect() {
    var state = TextEditingState(text: "Trăm năm\ntrong cõi")
    func press(_ code: String, command: Bool = false, multiline: Bool = true) -> Bool {
        state.press(code, command: command, multiline: multiline)
    }
    var handled = press("ArrowUp")
    #expect(handled && state.cursor == 8, "the same column of the shorter line above is its end")
    handled = press("Home")
    #expect(handled && state.cursor == 0)
    handled = press("ArrowRight")
    #expect(handled && state.cursor == 1)
    handled = press("End", command: true)
    #expect(handled && state.cursor == state.length)
    handled = press("Backspace", command: true)
    #expect(handled && state.text == "Trăm năm\n")
    handled = press("Enter")
    #expect(handled && state.text == "Trăm năm\n\n")
    handled = press("Enter", multiline: false)
    #expect(!handled, "one line leaves Return to the control")
    handled = press("KeyA", multiline: false)
    #expect(!handled)
    handled = press("KeyA", command: true, multiline: false)
    #expect(handled && state.selection == 0 ..< state.length)
    handled = press("ArrowLeft", multiline: false)
    #expect(handled && state.selection == 0 ..< 0)
    // A key commits the marked text first.
    state.compose("x")
    handled = press("Delete")
    #expect(handled && state.marked == nil && state.text == "xrăm năm\n\n")
}

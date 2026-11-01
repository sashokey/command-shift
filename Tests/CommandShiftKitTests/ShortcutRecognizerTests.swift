import CoreGraphics
import XCTest
@testable import CommandShiftKit

final class ShortcutRecognizerTests: XCTestCase {
    func testAdditionalModifiersCancelTheWholeGesture() {
        for modifier: CGEventFlags in [.maskControl, .maskAlternate, .maskSecondaryFn] {
            for beforeChord in [true, false] {
                var shortcut = ShortcutRecognizer()
                if beforeChord {
                    XCTAssertFalse(shortcut.handle(.flagsChanged, flags: [.maskCommand, modifier]))
                }
                XCTAssertFalse(shortcut.handle(.flagsChanged, flags: [.maskCommand, .maskShift, modifier]))
                XCTAssertFalse(shortcut.handle(.flagsChanged, flags: [.maskCommand, .maskShift]))
                XCTAssertFalse(shortcut.handle(.flagsChanged, flags: []), "\(modifier)")
                XCTAssertFalse(shortcut.handle(.flagsChanged, flags: [.maskCommand, .maskShift]))
                XCTAssertTrue(shortcut.handle(.flagsChanged, flags: []))
            }
        }
    }

    func testOtherInputCancelsChordUntilBothModifiersAreReleased() {
        let inputs: [CGEventType] = [
            .keyDown, .keyUp, .leftMouseDown, .leftMouseUp,
            .rightMouseDown, .rightMouseUp, .otherMouseDown, .otherMouseUp,
            .scrollWheel, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged
        ]
        for input in inputs {
            var shortcut = ShortcutRecognizer()
            XCTAssertFalse(shortcut.handle(.flagsChanged, flags: [.maskCommand, .maskShift]))
            XCTAssertFalse(shortcut.handle(input, flags: [.maskCommand, .maskShift]))
            XCTAssertFalse(shortcut.handle(.flagsChanged, flags: .maskCommand), "\(input)")
            XCTAssertFalse(shortcut.handle(.flagsChanged, flags: [.maskCommand, .maskShift]))
            XCTAssertFalse(shortcut.handle(.flagsChanged, flags: .maskShift), "\(input)")
            XCTAssertFalse(shortcut.handle(.flagsChanged, flags: []))
            XCTAssertFalse(shortcut.handle(.flagsChanged, flags: [.maskCommand, .maskShift]))
            XCTAssertTrue(shortcut.handle(.flagsChanged, flags: []))
        }
    }

    func testSwitchesOnceWhenCommandShiftIsReleased() {
        var shortcut = ShortcutRecognizer()
        XCTAssertFalse(shortcut.handle(.flagsChanged, flags: .maskShift))
        XCTAssertFalse(shortcut.handle(.flagsChanged, flags: [.maskShift, .maskCommand]))
        XCTAssertTrue(shortcut.handle(.flagsChanged, flags: .maskCommand))
        XCTAssertFalse(shortcut.handle(.flagsChanged, flags: []))
    }
}

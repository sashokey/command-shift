import XCTest
@testable import CommandShiftKit

final class InputSourceCycleTests: XCTestCase {
    func testFallsBackToFirstSourceWhenCurrentSourceIsUnavailable() {
        XCTAssertEqual(InputSourceCycle.next(after: "removed", in: ["en", "ru"]), "en")
        XCTAssertEqual(InputSourceCycle.next(after: nil, in: ["ru"]), "ru")
        XCTAssertNil(InputSourceCycle.next(after: "en", in: []))
        XCTAssertNil(InputSourceCycle.next(after: nil, in: []))
    }

    func testDoesNotReselectTheOnlyActiveSource() {
        XCTAssertNil(InputSourceCycle.next(after: "en", in: ["en"]))
    }

    func testSelectsNextSourceAndWrapsAtTheEnd() {
        XCTAssertEqual(InputSourceCycle.next(after: "en", in: ["en", "ru", "de"]), "ru")
        XCTAssertEqual(InputSourceCycle.next(after: "ru", in: ["en", "ru", "de"]), "de")
        XCTAssertEqual(InputSourceCycle.next(after: "de", in: ["en", "ru", "de"]), "en")
    }
}

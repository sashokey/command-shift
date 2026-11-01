import Carbon
import XCTest
@testable import CommandShiftKit

final class SystemInputSourcesTests: XCTestCase {
    func testSwitchForwardsTheChosenSourceAndSystemFailure() throws {
        try MainActor.assumeIsolated {
            let source = try XCTUnwrap(SystemInputSources.available().first)
            var selected: TISInputSource?
            let result = SystemInputSources.selectNext(
                readSources: { [source] },
                readCurrent: { nil },
                select: { selected = $0; return -50 }
            )
            XCTAssertEqual(selected, source)
            XCTAssertEqual(result, -50)
        }
    }

    func testCatalogContainsOnlyEnabledSelectableKeyboardSources() throws {
        try MainActor.assumeIsolated {
            let sources = SystemInputSources.available()
            XCTAssertFalse(sources.isEmpty)
            for source in sources {
                XCTAssertEqual(Self.property(source, kTISPropertyInputSourceCategory) as? String, kTISCategoryKeyboardInputSource as String)
                XCTAssertEqual(Self.property(source, kTISPropertyInputSourceIsEnabled) as? Bool, true)
                XCTAssertEqual(Self.property(source, kTISPropertyInputSourceIsSelectCapable) as? Bool, true)
                XCTAssertFalse(try XCTUnwrap(SystemInputSources.identifier(source)).isEmpty)
            }
        }
    }

    private static func property(_ source: TISInputSource, _ key: CFString) -> AnyObject? {
        guard let pointer = TISGetInputSourceProperty(source, key) else { return nil }
        return Unmanaged<AnyObject>.fromOpaque(pointer).takeUnretainedValue()
    }
}

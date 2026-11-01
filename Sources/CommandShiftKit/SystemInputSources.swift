import Carbon

@MainActor
enum SystemInputSources {
    static func selectNext(
        readSources: @MainActor () -> [TISInputSource] = available,
        readCurrent: @MainActor () -> TISInputSource? = { TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() },
        select: @MainActor (TISInputSource) -> OSStatus = { TISSelectInputSource($0) }
    ) -> OSStatus {
        let sources = readSources()
        let currentID = readCurrent().flatMap(identifier)
        guard let nextID = InputSourceCycle.next(after: currentID, in: sources.compactMap(identifier)),
              let next = sources.first(where: { identifier($0) == nextID }) else { return noErr }
        return select(next)
    }

    static func available() -> [TISInputSource] {
        let filter = [
            kTISPropertyInputSourceCategory: kTISCategoryKeyboardInputSource as Any,
            kTISPropertyInputSourceIsEnabled: true,
            kTISPropertyInputSourceIsSelectCapable: true
        ] as CFDictionary
        guard let list = TISCreateInputSourceList(filter, false)?.takeRetainedValue() else { return [] }
        return list as? [TISInputSource] ?? []
    }

    static func identifier(_ source: TISInputSource) -> String? {
        guard let pointer = TISGetInputSourceProperty(source, kTISPropertyInputSourceID) else { return nil }
        return Unmanaged<CFString>.fromOpaque(pointer).takeUnretainedValue() as String
    }
}

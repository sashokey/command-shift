import CoreGraphics

struct ShortcutRecognizer {
    private var armed = false
    private var cancelled = false

    mutating func handle(_ type: CGEventType, flags: CGEventFlags) -> Bool {
        guard type == .flagsChanged else {
            if armed || !flags.intersection([.maskCommand, .maskShift]).isEmpty {
                cancelled = true
            }
            return false
        }
        if !flags.intersection([.maskControl, .maskAlternate, .maskSecondaryFn]).isEmpty {
            cancelled = true
        }
        let pressed = flags.contains([.maskShift, .maskCommand])
        let shouldSwitch = armed && !pressed && !cancelled
        armed = pressed
        if flags.intersection([.maskCommand, .maskShift]).isEmpty {
            cancelled = false
        }
        return shouldSwitch
    }
}

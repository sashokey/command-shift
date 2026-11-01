enum InputSourceCycle {
    static func next(after current: String?, in sources: [String]) -> String? {
        guard let current, let index = sources.firstIndex(of: current) else { return sources.first }
        guard sources.count > 1 else { return nil }
        return sources[(index + 1) % sources.count]
    }
}

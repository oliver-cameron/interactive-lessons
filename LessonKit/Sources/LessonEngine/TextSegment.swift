import LessonModel

// Text with \var{name} references resolved to variables.
public enum TextSegment {
    case literal(String)
    case variable(Variable)

    // Splits "a is \var{a}" into segments. Returns the first unknown name instead, if any.
    @MainActor
    static func parse(_ text: String, in store: VariableStore) -> Result<[TextSegment], UnknownName> {
        var segments: [TextSegment] = []
        var rest = Substring(text)
        while let open = rest.range(of: "\\var{") {
            guard let close = rest[open.upperBound...].firstIndex(of: "}") else { break }
            let name = String(rest[open.upperBound..<close])
            guard let variable = store[name] else { return .failure(UnknownName(name: name)) }
            if open.lowerBound > rest.startIndex { segments.append(.literal(String(rest[..<open.lowerBound]))) }
            segments.append(.variable(variable))
            rest = rest[rest.index(after: close)...]
        }
        if !rest.isEmpty { segments.append(.literal(String(rest))) }
        return .success(segments)
    }

    @MainActor
    public static func render(_ segments: [TextSegment]) -> String {
        segments.map {
            switch $0 {
            case .literal(let s): s
            case .variable(let v): v.value.displayString
            }
        }.joined()
    }

    struct UnknownName: Error {
        let name: String
    }
}

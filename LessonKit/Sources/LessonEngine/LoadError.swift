import LessonModel

// Problems in the variables and functions sections, which stop a lesson loading.
// Problems in the component tree don't: they become ResolvedNode.error and render in place.
public enum LoadError: Error, Equatable, CustomStringConvertible {
    case duplicateName(String)
    case unknownInput(String, usedBy: String)
    case cycle([String])
    case unknownFunction(String, usedBy: String)
    case needsValueOrFunction(String)
    case unknownColour(String, usedBy: String)
    case scriptError(function: String, message: String)

    public var description: String {
        switch self {
        case .duplicateName(let name): "Two variables are named \(name)."
        case .unknownInput(let input, let user): "\(user) uses \(input), which isn't declared."
        case .cycle(let names): "These variables depend on each other in a loop: \(names.joined(separator: ", "))."
        case .unknownFunction(let fn, let user): "\(user) uses the function \(fn), which doesn't exist."
        case .needsValueOrFunction(let name): "\(name) needs exactly one of \"value\" or \"fn\"."
        case .unknownColour(let colour, let user):
            "\(user) uses the colour \(colour). Colours are \(PaletteColorNames.list)."
        case .scriptError(let fn, let message): "The JavaScript function \(fn) doesn't compile: \(message)"
        }
    }
}

enum PaletteColorNames {
    static let list = PaletteColor.allCases.map(\.rawValue).joined(separator: ", ")
}

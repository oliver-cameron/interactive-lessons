// Desmos notebook frontend, youtube backend. Interactive lessons and components, that would be user generated.
// Basically, we need swiftui from json.

import SwiftUI
import Combine

// A typed variable abstraction that can be persisted
//public protocol Variable: Codable {
//    associatedtype Value: Codable
//    var contents: Value { get set }
//    static var defaultValue: Self { get }
//    init(_ value: Value)
//}

// Type-erased handle to a variable for heterogeneous storage
//public protocol AnyVariable: ObservableObject {
//    // The runtime type of the underlying value
//    var valueType: Any.Type { get }
//
//    // Read the value as `Any` and set it back as `Any`
//    func getAny() -> Any
//    func setAny(_ newValue: Any)
//
//    // Produce a typed Binding when the caller knows the expected type
//    func binding<T>(default defaultValue: T) -> Binding<T>
//}
public enum Variable: Codable, Equatable {
    case String(String)
    case Bool(Bool)
    case Int(Int)
    case Double(Double)
    public func cast<T>() -> T? {
        switch self {
        case .String(let val as T): return val
        case .Bool(let val as T): return val
        case .Int(let val as T): return val
        case .Double(let val as T): return val
        default: return nil
        }
    }
}

//public struct String: Variable {
//    public var contents: Swift.String
//    public static var defaultValue: interactive_lessons.String { .init("") }
//    public init(_ value: Swift.String) { self.contents = value }
//}

// Store that components use to access variables by key

// Components are decoded from JSON and render using variables from a store
public protocol Component: Codable{
    // Initialize from a JSON string representation
    init(json: String)
    
    @ViewBuilder
    func body(using store: VariableStore) -> AnyView
}

public class VariableStore: Observable, Codable {

    @Published var values: [String : Variable] = [:]
    enum CodingKeys: CodingKey {case values}
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.values = try container.decode([String: Variable].self, forKey: .values)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(values, forKey: .values)
    }
    
    public func binding(for key: String) -> Binding<Variable> {
        Binding(get: { self.values[key] ?? .String("") }, set: { self.values[key] = $0 })
    }
    
}
// MARK: - Concrete Components

// A simple JSON shape each component can decode
private struct ComponentBase: Codable {
    let type: String
}

public struct VStackComponent: Component {
    
    public struct Model: Codable {
        public let spacing: CGFloat?
        public let children: [String] // JSON strings for child components
    }

    private let model: Model

    public init(json: String) {
        if let data = json.data(using: .utf8), let decoded = try? JSONDecoder().decode(Model.self, from: data) {
            self.model = decoded
        } else {
            self.model = Model(spacing: nil, children: [])
        }
    }

    public func body(using store: VariableStore) -> AnyView {
        AnyView(
            VStack(spacing: model.spacing) {
                ForEach(Array(model.children.enumerated()), id: \.offset) { _, childJSON in
                    let child = ComponentFactory.make(from: childJSON)
                    AnyComponentView(component: child, store: store)
                }
            }
        )
    }
}

public struct SliderComponent: Component {
    public struct Model: Codable {
        public let key: String // variable name to bind (Double)
        public let range: ClosedRange<Double>?
        public let step: Double?
    }

    private let model: Model

    public init(json: String) {
        if let data = json.data(using: .utf8), let decoded = try? JSONDecoder().decode(Model.self, from: data) {
            self.model = decoded
        } else {
            self.model = Model(key: "", range: nil, step: nil)
        }
    }

    @ViewBuilder
    public func body(using store: VariableStore) -> AnyView {
            let binding = store.binding(for: model.key)
            let range = model.range ?? 0.0...1.0
            if let step = model.step {
                Slider(value: binding, in: range, step: step)
            } else {
                Slider(value: binding, in: range)
            }
    }
}

public struct TextComponent: Component {
    public struct Model: Codable {
        public let key: String // variable name to bind (String)
    }

    private let model: Model

    public init(json: String) {
        if let data = json.data(using: .utf8), let decoded = try? JSONDecoder().decode(Model.self, from: data) {
            self.model = decoded
        } else {
            self.model = Model(key: "")
        }
    }
    @ViewBuilder
    public func body(using store: VariableStoreProtocol) -> some View {
        let text = store.binding(for: model.key, default: "")
        Text(text.wrappedValue)
    }
}
public struct EmptyComponent: Component {
    public init(json: String) {
        <#code#>
    }
    
    @ViewBuilder
    public func body(using store: VariableStore) -> some View {
        
    }
}

// MARK: - Component Factory and Erasure

public enum ComponentFactory {
    // Expects top-level object containing at least a `type` field
    public static func make(from json: String) -> any Component {
        // Try to extract type cheaply
        let type = extractType(from: json)
        switch type {
        case "vstack":
            return VStackComponent(json: json)
        case "slider":
            return SliderComponent(json: json)
        case "text":
            return TextComponent(json: json)
        default:
            return TextComponent(json: "{\"key\":\"unknown\"}")
        }
    }

    private static func extractType(from json: String) -> String {
        struct T: Codable { let type: String? }
        if let data = json.data(using: .utf8), let t = try? JSONDecoder().decode(T.self, from: data), let s = t.type {
            return s.lowercased()
        }
        return ""
    }
}

public struct AnyComponentView: View {
    private let _makeBody: (VariableStore) -> AnyView
    private let store: VariableStore

    public init(component: any Component, store: VariableStore) {
        self.store = store
        self._makeBody = { store in AnyView(component.body(using: store)) }
    }

    public var body: some View {
        _makeBody(store)
    }
}

public struct Lesson: View, Codable {
    public var body: AnyComponentView
    var store: VariableStore
    public init(from json: String) throws {
        
    }
    private static func extractComponents(from json: String) -> (VariableStore, AnyComponentView) {
        struct T: Codable {let body: any Component; let store: VariableStore}
        if let data = json.data(using: .utf8), let t = try? JSONDecoder().decode(T.self, from: data), let s = (t.store, t.body){
            return s
        }
        return (VariableStore(), AnyComponentView(component: EmptyComponent(json: ""), store: VariableStore()))
    }
}

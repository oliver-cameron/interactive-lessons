// Desmos notebook frontend, youtube backend. Interactive lessons and components, that would be user generated.
// Basically, we need swiftui from json.

import SwiftUI
import Combine

enum StorageValue: Equatable {
    case integer(Int)
    case float(Double)
    case string(String)
    case boolean(Bool)
}

extension StorageValue: Codable {
    enum StorageType: Codable {
        case integer
        case float
        case string
        case boolean
    }
    enum CodingKeys: CodingKey {
        case type
        case contents
    }
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(StorageType.self, forKey: .type)
        switch type {
        case .integer:
            self = .integer(try container.decode(Int.self, forKey: .contents))
        case .float:
            self = .float(try container.decode(Double.self, forKey: .contents))
        case .string:
            self = .string(try container.decode(String.self, forKey: .contents))
        case .boolean:
            self = .boolean(try container.decode(Bool.self, forKey: .contents))
        }
    }
    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
            case .integer(let v):
                try container.encode(v, forKey: .contents)
                try container.encode(StorageType.integer, forKey: .type)
        case .float(let v):
            try container.encode(v, forKey: .contents)
            try container.encode(StorageType.float, forKey: .type)
        case .string(let v):
            try container.encode(v, forKey: .contents)
            try container.encode(StorageType.string, forKey: .type)
        case .boolean(let v):
            try container.encode(v, forKey: .contents)
            try container.encode(StorageType.boolean, forKey: .type)
        }
    }
}

@Observable
class GlobalVariableStore: Codable {
    var registry: [String: StorageValue]
    
    func binding<T>(for key: String, cast: @escaping (StorageValue) -> T?, transform: @escaping(T) -> StorageValue) -> Binding<T> where T: Equatable {
        Binding(
            get: {
                guard let rawValue = self.registry[key], let typedValue = rawValue.value() else {
                    fatalError("Missing or mis-typed storage mapping context for key: \(key)")
                }
                return typedValue
            },
            set: {newValue in
                self.registry[key] = transform(newValue)
            }
        )
    }
    init(registry: [String : StorageValue]) {
        self.registry = registry
    }
    enum CodingKeys: CodingKey {
        case registry
    }
    required init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.registry = try container.decode([String : StorageValue].self, forKey: .registry)
    }
    
    func encode(to encoder: any Encoder) throws {
        var container = encoder
    }
}

extension StorageValue {
    // Pull the value out of the storagevalue enum
    func Type() -> SendableMetatype {
        switch self {
            case .integer(_): return Int.self
            case .boolean(_): return Bool.self
            case .float(_): return Double.self
            case .string(_): return String.self
        }
    }
    func Value() -> Self.Type {
        switch self {
            case .integer(let v): return v
        }
    }
}

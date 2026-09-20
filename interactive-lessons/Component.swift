//
//  Components.swift
//  interactive-lessons
//
//  Created by Oliver Cameron on 20/9/26.
//

import SwiftUI

protocol Component: View, Decodable {}


struct EmptyComponent: Component {
    init() {}
    init(from decoder: Decoder) throws { self.init() }
    var body: some View { EmptyView() }
}



struct AnyComponent: View, Decodable {
    let type: ComponentType
    private let _view: AnyView

    enum CodingKeys: String, CodingKey { case type }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.type = try container.decode(ComponentType.self, forKey: .type)
        
        self._view = switch type {
            case .VStack:  AnyView(try VStackComponent(from: decoder))
            default: AnyView(EmptyComponent())
        }
    }

    var body: some View { _view }
}


enum ComponentType: String, Codable {
    case VStack
    case Text
    case Slider
    case Empty
}

// MARK: VSTACK
// A VStack component that holds an array of AnyComponent decoded from JSON
struct VStackComponent: Component {
    
    @Environment(GlobalVariableStore.self) private var store
    let contents: [AnyComponent]

    enum CodingKeys: String, CodingKey { case contents }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.contents = try container.decodeIfPresent([AnyComponent].self, forKey: .contents) ?? []
    }

    var body: some View {
        VStack {
            ForEach(contents.indices, id: \.self) { idx in
                contents[idx]
            }
        }
    }
}

// MARK: Text

protocol JSONTextInterpolatable: Component {
    func asAttributedString() -> AttributedString
}


struct TextComponent: JSONTextInterpolatable {
    var text: String
    @Environment(GlobalVariableStore.self) private var store
    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.text = try container.decode(String.self)
    }
    var body: some View {
        Text(self.text)
    }
    func asAttributedString() -> AttributedString {
        var attStr = AttributedString(text)
        return attStr
    }
}

// MARK: Slider
struct SliderComponent: Component {
    @
}

struct Message {
    let value: String
}

extension Message : MapInitializable {
    init(map: Map) throws {
        self.value = try map.get("value")
    }
}

try λ { (message: Message, context: Context?) in
    message.value.uppercased()
}

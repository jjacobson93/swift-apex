import Apex

struct Event {
    let message: String
}

extension Event : MapInitializable {
    init(map: Map) throws {
        self.message = try map.get("message")
    }
}

try λ { (event: Event, context) in
    event.message.uppercased()
}

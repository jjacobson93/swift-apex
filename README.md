# Apex Swift

Swift runtime support for Apex/Lambda – providing handlers for Lambda sources, and runtime requirements such as implementing the Node.js shim stdio interface.

## Features

Currently supports:

- Node.js shim

## Example

```swift
import Apex

struct Event {
    let message: String
}

extension Event : MapInitializable {
    init(map: Map) throws {
        self.message = try map.get("message")
    }
}

try λ { (event: Event, context: Context?) in
    event.message.uppercased()
}
```

Run the program:

```sh
swift build
echo '{"event":{"message":"Hello World!"}}' | .build/debug/Apex
{"value":"HELLO WORLD!"}
```

## Notes

 Due to the Node.js [shim](http://apex.run/#understanding-the-shim) required to run Swift in Lambda, you __must__ use stderr for logging – stdout is reserved for the shim.

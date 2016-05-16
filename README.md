
# Apex Swift

Swift runtime support for Apex/Lambda – providing handlers for Lambda sources, and runtime requirements such as implementing the Node.js shim stdio interface.

## Features

Currently supports:

- Node.js shim

## Example

```swift
import Apex

try handle { message, _ in
    return message
}
```

Run the program:

```sh
swift build
echo '{"event":{"value":"Hello World!"}}' | .build/debug/Apex
{"value":{"value":"Hello World!"}}
```

## Notes

 Due to the Node.js [shim](http://apex.run/#understanding-the-shim) required to run Swift in Lambda, you __must__ use stderr for logging – stdout is reserved for the shim.

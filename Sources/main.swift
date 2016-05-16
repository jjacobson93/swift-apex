import Jay

try handle { message, _ in
    guard let greeting = message.dictionary?["value"]?.string else {
        //TODO: improve dictionary/array convertible in Jay to get rid
        //of the explicit conversions here
        return .Object(["error": .String("Unexpected message")])
    }
    return .String(greeting.uppercased())
}
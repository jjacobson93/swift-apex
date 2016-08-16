public struct Context {
    public let invokeID: String
    public let requestID: String
    public let functionName: String
    public let functionVersion: String
    public let logGroupName: String
    public let logStreamName: String
    public let memoryLimitInMB: String
    public let isDefaultFunctionVersion: Bool
    public let clientContext: Map
}

extension Context {
    public init(map: Map) throws {
        invokeID = try map.get("invokeid")
        requestID = try map.get("awsRequestId")
        functionName = try map.get("functionName")
        functionVersion = try map.get("functionVersion")
        logGroupName = try map.get("logGroupName")
        logStreamName = try map.get("logStreamName")
        memoryLimitInMB = try map.get("memoryLimitInMB")
        isDefaultFunctionVersion = try map.get("isDefaultFunctionVersion")
        clientContext = map["clientContext"]
    }
}

public typealias Lambda<T> = @escaping (_ event: T, _ context: Context?) throws -> MapRepresentable

public func λ <T : MapInitializable>(lambda: Lambda<T>) throws {
    let inputChannel = input()
    let outputChannel = handle(inputChannel, lambda: lambda)
    try output(outputChannel)
}

func input() -> FallibleChannel<Map> {
    let parser = JSONMapStreamParser(stream: standardInputStream)
    let inputChannel = FallibleChannel<Map>()

    co {
        while true {
            do {
                let input = try parser.parse()
                inputChannel.send(input)
            } catch {
                parser.reset()
                inputChannel.send(error)
                if error is StreamError {
                    inputChannel.close()
                    break
                }
            }
        }
    }

    return inputChannel
}

func handle<T : MapInitializable>(_ inputChannel: FallibleChannel<Map>, lambda: Lambda<T>) -> FallibleChannel<Map> {
    let outputChannel = FallibleChannel<Map>()
    // let waitGroup = WaitGroup()

    co {
        for result in inputChannel {
            // waitGroup.add()
            co {
                switch result {
                case .value(let message):
                    do {
                        let event = try T(map: message["event"])
                        let context = try? Context(map: message["context"])
                        let value = try lambda(event, context)
                        outputChannel.send(value.map)
                    } catch {
                        outputChannel.send(error)
                    }
                case .error(let error):
                    outputChannel.send(error)
                    if error is StreamError {
                        outputChannel.close()
                        break
                    }
                }
                // waitGroup.done()
            }
        }
        // waitGroup.wait()
    }

    return outputChannel
}

func output(_ channel: FallibleChannel<Map>) throws {
    let serializer = JSONMapStreamSerializer(stream: standardOutputStream)
    for result in channel {
        switch result {
        case .value(let value):
            try serializer.serialize(["value": value])
            try standardOutputStream.write("\n")
            try standardOutputStream.flush()
        case .error(let error):
            if error is StreamError {
                break
            }
            let errorDescription = String(describing: error)
            try serializer.serialize(["error": .string(errorDescription)])
            try standardOutputStream.write("\n")
            try standardOutputStream.flush()
        }
    }
}

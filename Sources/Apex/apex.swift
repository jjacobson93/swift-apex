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

enum Output {
    case value(Map)
    case error(String)
}

extension Output : MapRepresentable {
    var map: Map {
        switch self {
        case .value(let value):
            return ["value": value]
        case .error(let error):
            return ["error": .string(error)]
        }
    }
}

public typealias InitializableHandleFunction<T> = @escaping (_ event: T, _ context: Context?) throws -> MapRepresentable
public typealias HandleFunction = @escaping (_ event: Map, _ context: Context?) throws -> MapRepresentable

public func λ <T : MapInitializable>(handleFunction: InitializableHandleFunction<T>) throws {
    try λ { (map: Map, context: Context?) throws -> MapRepresentable in
        return try handleFunction(T(map: map), context)
    }
}

public func λ(handleFunction: HandleFunction) throws {
    let inputChannel = input()
    let outputChannel = handle(inputChannel, handleFunction: handleFunction)
    try output(outputChannel)
}

func input() -> FallibleChannel<Map> {
    let parser = JSONMapStreamParser(stream: standardInputStream)
    let inputChannel = FallibleChannel<Map>()

    co {
        while true {
            do {
                let message = try parser.parse()
                inputChannel.send(message)
            } catch {
                inputChannel.send(error)
                break
            }
        }
    }

    return inputChannel
}

func handle(_ inputChannel: FallibleChannel<Map>, handleFunction: HandleFunction) -> FallibleChannel<Output> {
    let outputChannel = FallibleChannel<Output>()
    // let waitGroup = WaitGroup()

    co {
        for result in inputChannel {
            // waitGroup.add()
            switch result {
            case .value(let message):
//                co {
                    let output = invoke(message, handleFunction: handleFunction)
                    outputChannel.send(output)
                    // waitGroup.done()
//                }
            case .error(let error):
                outputChannel.send(error)
                break
            }

        }

        // waitGroup.wait()
    }

    return outputChannel
}

func invoke(_ message: Map, handleFunction: HandleFunction) -> Output {
    do {
        let value = try handleFunction(
            message["event"],
            try? Context(map: message["context"])
        )
        return .value(value.map)
    } catch {
        return .error(String(describing: error))
    }
}

func output(_ channel: FallibleChannel<Output>) throws {
    let serializer = JSONMapStreamSerializer(stream: standardOutputStream)

    for result in channel {
        switch result {
        case .value(let message):
            try serializer.serialize(message.map)
        case .error(let error):
            throw error
        }
    }
}

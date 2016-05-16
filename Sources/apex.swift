// Package apex provides Lambda support for Swift via a
// Node.js shim and this package for operating over
// stdio.
import Venice
import File
import JSON

// Context represents the context data provided by a Lambda invocation.
public struct Context {
    public let invokeID: String               //`json:"invokeid"`
    public let requestID: String              //`json:"awsRequestId"`
    public let functionName: String           //`json:"functionName"`
    public let functionVersion: String        //`json:"functionVersion"`
    public let logGroupName: String           //`json:"logGroupName"`
    public let logStreamName: String          //`json:"logStreamName"`
    public let memoryLimitInMB: String        //`json:"memoryLimitInMB"`
    public let isDefaultFunctionVersion: Bool //`json:"isDefaultFunctionVersion"`
    public let clientContext: JSON            //`json:"clientContext"`
}

// input for the node shim.
struct Input {
    let event: JSON      // `json:"event"`
    let context: Context? // `json:"context"`
}

// output from the node shim.
enum Output {
    case error(String) // `json:"error,omitempty"`
    case value(JSON)   // `json:"value,omitempty"`
}

// Handle Lambda event.
public func handle(handler: (event: JSON, context: Context?) throws -> JSON) throws {
    let reader = try File(fileDescriptor: STDIN_FILENO)
    let writer = try File(fileDescriptor: STDOUT_FILENO)

    // Start the manager.
    func start() {
        output(handle(input()))
    }

    // input reads from the Reader and decodes JSON messages.
    func input() -> Channel<Input> {
        let channel = Channel<Input>()

        co {
            while true {
                do {
                    let message = try decode(from: reader)
                    channel.send(message)
                } catch {
                    //print("error decoding input: \(error)")
                    break
                }
            }
        }

        return channel
    }

    // handle invokes the handler and sends the response to the output channel
    func handle(_ input: Channel<Input>) -> Channel<Output> {
        let channel = Channel<Output>()
        // var wg sync.WaitGroup

        co {
            for message in input {
                //wg.Add(1)

                co {
                    let output = invoke(message)
                    channel.send(output)
                    // wg.Done()
                }
            }

            //wg.Wait()
        }

        return channel
    }

    // invoke calls the handler with `msg`.
    func invoke(_ message: Input) -> Output {
        do {
            let value = try handler(event: message.event, context: message.context)
            return .value(value)
        } catch {
            return .error("\(error)")
        }
    }

    // output encodes the JSON messages and writes to the Writer.
    func output(_ channel: Channel<Output>) {
        for message in channel {
            do {
                try encode(message, to: writer)
            } catch {
                print("error encoding output: \(error)")
            }
        }
    }

    start()
}

enum DecodeError: ErrorProtocol {
    case invalidInput
}

func decode(from reader: File) throws -> Input  {
    let data = try reader.readAllBytes()
    let JSON = try JSONParser().parse(data: data)
    guard let event = JSON["event"] else {
        throw DecodeError.invalidInput
    }
    return Input(event: event, context: nil)
}

func encode(_ message: Output, to writer: File) throws {
    switch message {
        case .value(let v):
            let output: JSON = ["value": v]
            let data = JSONSerializer().serialize(json: output)
            try writer.write(data)
        case .error(let e):
            let output: JSON = ["error": .stringValue(e)]
            let data = JSONSerializer().serialize(json: output)
            try writer.write(data)
    }
}
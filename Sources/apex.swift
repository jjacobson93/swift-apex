// Package apex provides Lambda support for Swift via a
// Node.js shim and this package for operating over
// stdio.
import Venice
import File
import Jay

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
    case noBytes
}

func decode(from reader: File) throws -> Input  {
    
//  Standard: read all, parse, process
//    let data = try reader.readAllBytes().bytes
//    let json = try Jay().typesafeJsonFromData(data)
    
//  Hopefully faster: read chunks, return if parsed, throw otherwise
    let streamReader = try FileReader(file: reader)
    let json = try Jay().typesafeJsonFromReader(streamReader)
    guard let event = json.dictionary?["event"] else {
        throw DecodeError.invalidInput
    }
    return Input(event: event, context: nil)
}

func encode(_ message: Output, to writer: File) throws {
    switch message {
        case .value(let v):
            let output: JSON = JSON.Object(["value": v])
            let data = try Jay().dataFromJson(json: output)
            try writer.write(Data(data))
        case .error(let e):
            let output = JSON.Object(["error": .String(e)])
            let data = try Jay().dataFromJson(json: output)
            try writer.write(Data(data))
    }
}

class FileReader: Reader {
    
    let file: File
    private var currentByte: Byte
    
    init(file: File) throws {
        self.file = file
        let byte = try FileReader.getNextByte(file: file)
        self.currentByte = byte
    }
    
    //MARK: Conform to Reader
    
    private class func getNextByte(file: File) throws -> Byte {
        guard let nextByte = try file.read(upTo: 1).bytes.first else {
            throw DecodeError.noBytes
        }
        return nextByte
    }
    
    func curr() -> UInt8 {
        return currentByte
    }
    
    func next() throws {
        self.currentByte = try FileReader.getNextByte(file: file)
    }
    
    func isDone() -> Bool {
        return file.eof || file.closed
    }
    
    func finishParsingWhenValid() -> Bool {
        //since the file stays open, we can't wait to "finish" reading, let's
        //return when a valid JSON object has been parsed.
        return true
    }
}

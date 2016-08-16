@_exported import struct Foundation.Data

public typealias Byte = UInt8

public protocol DataInitializable {
    init(data: Data) throws
}

public protocol DataRepresentable {
    var data: Data { get }
}

extension Data : DataRepresentable {
    public var data: Data {
        return self
    }
}

public protocol DataConvertible : DataInitializable, DataRepresentable {}

#if os(Linux)
extension Data {
    public init(count: Int) {
        self = Data(count: count)!
    }

    public init(_ bytes: [UInt8]) {
        self = bytes.withUnsafeBufferPointer {
            Data(bytes: UnsafeRawPointer($0.baseAddress!), count: $0.count)
        }
    }
}
#endif

extension Data {
    public init(_ string: String) {
        // TODO: How can this fail?
        self = string.data(using: String.Encoding.utf8)!
    }
}

enum StringError : Error {
    case invalidString
}

extension String : DataConvertible {
    public init(data: Data) throws {
        guard let string = String(data: data, encoding: String.Encoding.utf8) else {
            throw StringError.invalidString
        }
        self = string
    }

    public var data: Data {
        return Data(self)
    }
}

extension Data {
    public func hexadecimalString(inGroupsOf characterCount: Int = 0) -> String {
        var string = ""
        for (index, value) in self.enumerated() {
            if characterCount != 0 && index > 0 && index % characterCount == 0 {
                string += " "
            }
            string += (value < 16 ? "0" : "") + String(value, radix: 16)
        }
        return string
    }

    public var hexadecimalDescription: String {
        return hexadecimalString(inGroupsOf: 2)
    }
}

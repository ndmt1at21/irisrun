import Foundation
import IrisProtocol
import SwiftProtobuf
import Testing

@Test func sizeDelimitedEnvelopesRoundTrip() throws {
    var touch = IrisHostMessage()
    touch.input.touch.touches = [
        IrisTouchPoint.with {
            $0.id = 1
            $0.phase = .began
            $0.x = 10.5
            $0.y = 20
        },
    ]
    var text = IrisHostMessage()
    text.input.text.commitText = "Tiếng Việt"
    let sent = [touch, text]

    let output = OutputStream.toMemory()
    output.open()
    for message in sent {
        try BinaryDelimited.serialize(message: message, to: output)
    }
    output.close()
    let stream = try #require(output.property(forKey: .dataWrittenToMemoryStreamKey) as? Data)

    let input = InputStream(data: stream)
    input.open()
    defer { input.close() }
    let received = try sent.map { _ in
        try BinaryDelimited.parse(messageType: IrisHostMessage.self, from: input)
    }

    #expect(received == sent)
}

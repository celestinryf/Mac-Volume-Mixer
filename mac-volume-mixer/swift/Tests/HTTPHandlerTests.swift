import XCTest
import NIO
import NIOHTTP1
@testable import MyAudioServer

final class HTTPHandlerTests: XCTestCase {
    func testHandleGetApps() async throws {
        let controller = AudioController()
        let handler = HTTPHandler(controller: controller)
        let context = MockChannelHandlerContext()

        // Simulate a GET request to `/apps`
        let requestHead = HTTPRequestHead(version: .http1_1, method: .GET, uri: "/apps")
        handler.channelRead(context: context, data: handler.wrapInboundIn(.head(requestHead)))
        handler.channelRead(context: context, data: handler.wrapInboundIn(.end(nil)))

        // Validate the response
        XCTAssertTrue(context.writtenResponses.contains { $0.status == .ok })
    }
}

// Mock ChannelHandlerContext for testing
class MockChannelHandlerContext: ChannelHandlerContext {
    var writtenResponses: [HTTPResponseHead] = []

    func write(_ data: NIOAny, promise: EventLoopPromise<Void>?) {
        if let part = unwrapOutboundOut(data) as? HTTPServerResponsePart {
            switch part {
            case .head(let responseHead):
                writtenResponses.append(responseHead)
            default:
                break
            }
        }
    }

    // Other required methods...
}
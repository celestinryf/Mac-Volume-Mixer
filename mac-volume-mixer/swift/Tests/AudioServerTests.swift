import XCTest
@testable import MyAudioServer

final class AudioServerTests: XCTestCase {
    func testStartAndStop() async throws {
        let server = AudioServer()
        try await server.start(host: "127.0.0.1", port: 8080)
        XCTAssertNotNil(server.channel?.localAddress)
        try await server.stop()
    }
}
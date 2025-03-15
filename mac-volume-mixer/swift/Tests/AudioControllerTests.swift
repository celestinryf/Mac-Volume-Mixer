import XCTest
@testable import MyAudioServer

final class AudioControllerTests: XCTestCase {
    func testSetAppVolume() async throws {
        let controller = AudioController()
        let success = try await controller.setAppVolume(pid: 123, volume: 0.5)
        XCTAssertTrue(success)
    }

    func testGetAudioApps() async throws {
        let controller = AudioController()
        let apps = try await controller.getAudioApps()
        XCTAssertFalse(apps.isEmpty)
    }
}
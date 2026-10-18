import Testing
@testable import StrapLogCore

@MainActor
@Suite("Forget strap")
struct ForgetStrapTests {
    let clock = FakeClock()
    let model: RecorderModel

    init() throws {
        model = RecorderModel(database: try .inMemory(), exports: ExportFolder(local: try scratchDirectory()), clock: clock)
    }

    func connectedSpy() async -> HeartSourceSpy {
        let spy = HeartSourceSpy(FakeHeartSource(clock: clock, script: [
            .emit(.connected(deviceId: "H10-1", firmware: nil)), .emit(.battery(percent: 80)),
            .emit(.firmware("3.1")), .emit(.serialNumber("S1")),
            .emit(.heartRate(bpm: 60, contact: true, rr1024: [1024])),
        ]))
        await model.launch()
        await model.consume(spy)
        return spy
    }

    @Test("forgetting tells the source and clears what the old strap reported")
    func forgets() async throws {
        let spy = await connectedSpy()
        model.forgetStrap()
        #expect(spy.forgets == 1)
        #expect(model.link == .searching)
        #expect(model.battery == nil && model.firmware == nil && model.serialNumber == nil)
        #expect(model.heartRate == nil && model.contact == nil)
    }

    @Test("refused while recording")
    func refusedWhileRecording() async throws {
        let spy = await connectedSpy()
        await model.start(name: "r")
        model.forgetStrap()
        #expect(spy.forgets == 0)
        #expect(model.link == .connected(deviceId: "H10-1"))
    }
}

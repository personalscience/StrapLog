import GRDB
import Testing
@testable import StrapLogCore

@Suite("Harness")
struct HarnessTests {
    @Test("StrapLogCore test harness runs")
    func harnessRuns() {
        #expect(StrapLogCore.version.isEmpty == false)
    }

    @Test("GRDB links and opens an in-memory database")
    func grdbLinks() throws {
        let db = try DatabaseQueue()
        let one = try db.read { try Int.fetchOne($0, sql: "SELECT 1") }
        #expect(one == 1)
    }
}

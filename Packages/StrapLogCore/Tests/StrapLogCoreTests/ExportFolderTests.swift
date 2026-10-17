import Foundation
import Synchronization
import Testing
@testable import StrapLogCore

@Suite("ExportFolder")
struct ExportFolderTests {
    private let local = URL(fileURLWithPath: "/tmp/local")
    private let cloud = URL(fileURLWithPath: "/tmp/cloud")

    @Test("without a cloud resolver, the local folder")
    func localOnly() async {
        #expect(await ExportFolder(local: local).url() == local)
    }

    @Test("a cloud miss falls back to local and is retried; a hit is kept")
    func cloudRetriedUntilFound() async {
        let calls = Mutex(0)
        let cloud = self.cloud
        let folder = ExportFolder(local: local) {
            calls.withLock { $0 += 1; return $0 >= 2 ? cloud : nil }
        }
        #expect(await folder.url() == local)
        #expect(await folder.url() == cloud)
        #expect(await folder.url() == cloud)
        #expect(calls.withLock { $0 } == 2)
    }

    @Test("all() lists iCloud then local, or local alone")
    func allFolders() async {
        let cloud = self.cloud
        #expect(await ExportFolder(local: local).all() == [local])
        #expect(await ExportFolder(local: local) { nil }.all() == [local])
        #expect(await ExportFolder(local: local) { cloud }.all() == [cloud, local])
    }
}

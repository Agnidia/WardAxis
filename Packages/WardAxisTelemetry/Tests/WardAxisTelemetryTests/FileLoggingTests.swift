import Foundation
import Testing
@testable import WardAxisTelemetry

@Suite("Bounded file logging")
struct FileLoggingTests {
    private func temporaryFile() -> URL {
        FileManager.default.temporaryDirectory.appending(path: "WardAxis-log-\(UUID()).log")
    }

    @Test
    func `Startup rotation and pending writes cannot restore cleared entries`() async throws {
        let url = temporaryFile()
        defer { try? FileManager.default.removeItem(at: url) }
        let oldLine = "[ui] [info] " + String(repeating: "x", count: 40) + "\n"
        try Data(String(repeating: oldLine, count: 110_000).utf8).write(to: url)
        let writer = try FileLogHandler(label: "test", localFile: url)
        #expect(try Data(contentsOf: url).count <= LogFileLimits.maximumFileBytes)
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<100 {
                group.addTask { writer.log(entry: "[ui] [error] old") }
            }
        }
        try await writer.clear()
        await writer.drain()
        #expect(try Data(contentsOf: url).isEmpty)
        writer.log(entry: "[ui] [error] new")
        await writer.drain()
        #expect(try String(contentsOf: url, encoding: .utf8) == "[ui] [error] new\n")
    }

    @Test
    func `Every append respects the byte limit and retains complete recent lines`() throws {
        let url = temporaryFile()
        defer { try? FileManager.default.removeItem(at: url) }
        var file = try BoundedLogFile(url: url, maximumBytes: 128, retainedBytes: 64)
        defer { try? file.close() }
        for number in 0..<100 {
            try file.append(Data("[ui] [info] entry \(number)\n".utf8))
            #expect(try Data(contentsOf: url).count <= 128)
        }
        #expect(try String(contentsOf: url, encoding: .utf8).hasSuffix("entry 99\n"))
        try file.append(Data(repeating: 120, count: 128))
        #expect(try Data(contentsOf: url).count == 128)
    }

    @Test
    func `A failed truncate throws instead of confirming deletion`() throws {
        let url = temporaryFile()
        defer { try? FileManager.default.removeItem(at: url) }
        var file = try BoundedLogFile(url: url, maximumBytes: 128, retainedBytes: 64)
        try file.append(Data("entry\n".utf8))
        try file.close()
        #expect(throws: (any Error).self) { try file.clear() }
        #expect(try String(contentsOf: url, encoding: .utf8) == "entry\n")
    }

    @Test
    func `Oversize Unicode entries are capped without splitting a scalar`() {
        let data = FileLogHandler.boundedEntry(String(repeating: "🔒", count: 10_000))
        #expect(data.count <= LogFileLimits.maximumEntryBytes)
        #expect(String(data: data, encoding: .utf8)?.hasSuffix(" [truncated]\n") == true)
    }

    @Test
    func `A tail read discards a cut line and never reads over its budget`() throws {
        let url = temporaryFile()
        defer { try? FileManager.default.removeItem(at: url) }
        try Data((String(repeating: "x", count: 10_000) + "\n[ui] [info] recent\n").utf8).write(to: url)
        let tail = try LogFileTail.read(from: url, maximumBytes: 64)
        #expect(String(data: tail, encoding: .utf8) == "[ui] [info] recent\n")
        try Data(repeating: 120, count: 10_000).write(to: url)
        #expect(try LogFileTail.read(from: url, maximumBytes: 64).isEmpty)
    }
}

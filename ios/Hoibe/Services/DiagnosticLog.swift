import Foundation

/// Simple file logger that writes to Documents/hoibe_debug.log.
/// Pull from device via:
///   xcrun devicectl device copy from --device <id> \
///     --domain-type appDataContainer --domain-identifier com.hoibe.app \
///     --source Documents/hoibe_debug.log --destination /tmp/hoibe_debug.log
enum DiagnosticLog {
    private static let fileURL: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("hoibe_debug.log")
    }()

    static func clear() {
        try? FileManager.default.removeItem(at: fileURL)
    }

    static func log(_ message: String) {
        let ts = ISO8601DateFormatter().string(from: Date())
        let line = "[\(ts)] \(message)\n"
        print(line, terminator: "")
        if let data = line.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: fileURL.path) {
                if let handle = try? FileHandle(forWritingTo: fileURL) {
                    handle.seekToEndOfFile()
                    handle.write(data)
                    handle.closeFile()
                }
            } else {
                try? data.write(to: fileURL)
            }
        }
    }
}

import CoreImage
import Foundation
import Hub
import MLX
import MLXLMCommon
import MLXVLM

/// Manages VLM model download, caching, and inference using MLX Swift.
public final class ModelManager: ModelManaging, @unchecked Sendable {

    private let modelId: String
    private var container: ModelContainer?
    private let lock = NSLock()

    /// HubApi that always allows downloads (overrides NetworkMonitor's isExpensive/isConstrained check).
    private static let hubApi: HubApi = {
        HubApi(
            downloadBase: FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first,
            useOfflineMode: false
        )
    }()

    @Published public private(set) var state: ModelDownloadState = .notDownloaded

    public var isReady: Bool {
        if case .ready = state { return true }
        return false
    }

    /// Progress callback set by the caller before starting download.
    public var onProgress: (@Sendable (Double) -> Void)?

    public init(modelId: String) {
        self.modelId = modelId
    }

    /// Try to load model from local cache (no download). Returns true if cached and ready.
    public func tryLoadCached() async -> Bool {
        let destDir = Self.cacheBaseURL.appending(component: modelId)
        let configFile = destDir.appending(component: "config.json")
        guard FileManager.default.fileExists(atPath: configFile.path) else {
            print("[ModelManager] No cached model at \(destDir.path)")
            return false
        }
        // Verify at least one .safetensors file exists (config alone = incomplete download)
        let contents = (try? FileManager.default.contentsOfDirectory(atPath: destDir.path)) ?? []
        let hasSafetensors = contents.contains { $0.hasSuffix(".safetensors") }
        guard hasSafetensors else {
            print("[ModelManager] Cache incomplete (no .safetensors) at \(destDir.path) — will re-download")
            return false
        }
        do {
            print("[ModelManager] Loading cached model from \(destDir.path)…")
            let container = try await loadModelContainer(hub: Self.hubApi, directory: destDir) { _ in }
            lock.lock()
            self.container = container
            lock.unlock()
            state = .ready
            return true
        } catch {
            print("[ModelManager] Failed to load cached model: \(error)")
            return false
        }
    }

    public func startDownload(allowCellular: Bool) async throws {
        state = .downloading(progress: 0)

        print("[ModelManager] Starting download for \(modelId)…")
        let destDir = Self.cacheBaseURL
            .appending(component: modelId)
        print("[ModelManager] Destination: \(destDir.path)")

        // URLSession that explicitly allows expensive+constrained networks (cellular, Low Data Mode)
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.allowsExpensiveNetworkAccess = true
        sessionConfig.allowsConstrainedNetworkAccess = true
        sessionConfig.waitsForConnectivity = false
        sessionConfig.timeoutIntervalForRequest = 60
        sessionConfig.timeoutIntervalForResource = 3600 // 1 hour max per file (model.safetensors ~1.7 GB)
        let session = URLSession(configuration: sessionConfig)

        // Quick connectivity check
        let reachable = await Self.checkHuggingFaceReachable(session: session)
        print("[ModelManager] HuggingFace reachable: \(reachable)")
        if !reachable {
            throw ModelManagerError.networkUnavailable
        }

        // 1. List files from HF API
        let listURL = URL(string: "https://huggingface.co/api/models/\(modelId)/revision/main")!
        print("[ModelManager] Fetching file list from \(listURL)…")
        let (listData, _) = try await session.data(from: listURL)
        print("[ModelManager] Got file list (\(listData.count) bytes)")
        let siblings = try JSONDecoder().decode(HFSiblingsResponse.self, from: listData).siblings
        let filenames = siblings.map(\.rfilename).filter { name in
            name.hasSuffix(".safetensors") || name.hasSuffix(".json")
        }
        print("[ModelManager] Found \(filenames.count) files to download")

        // 2. Download each file
        let fm = FileManager.default
        try fm.createDirectory(at: destDir, withIntermediateDirectories: true)

        for (index, filename) in filenames.enumerated() {
            let fileURL = destDir.appending(path: filename)
            if fm.fileExists(atPath: fileURL.path) {
                print("[ModelManager] [\(index+1)/\(filenames.count)] Skipping \(filename) (exists)")
                let frac = Double(index + 1) / Double(filenames.count)
                onProgress?(frac)
                continue
            }

            // Create subdirectories if needed
            let parent = fileURL.deletingLastPathComponent()
            try fm.createDirectory(at: parent, withIntermediateDirectories: true)

            let downloadURL = URL(string: "https://huggingface.co/\(modelId)/resolve/main/\(filename)")!
            print("[ModelManager] [\(index+1)/\(filenames.count)] Downloading \(filename) from \(downloadURL)…")

            let (tempURL, response) = try await session.download(from: downloadURL)
            let httpStatus = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard (200..<400).contains(httpStatus) else {
                print("[ModelManager] HTTP \(httpStatus) for \(filename)")
                throw ModelManagerError.downloadFailed(filename: filename, status: httpStatus)
            }

            let fileSize = (try? fm.attributesOfItem(atPath: tempURL.path)[.size] as? Int) ?? 0
            try fm.moveItem(at: tempURL, to: fileURL)
            let frac = Double(index + 1) / Double(filenames.count)
            print("[ModelManager] [\(index+1)/\(filenames.count)] Done \(filename) (\(fileSize / 1_048_576) MB) — \(Int(frac * 100))%")
            onProgress?(frac)
        }

        session.invalidateAndCancel()
        print("[ModelManager] All files downloaded ✓ — loading model…")

        // 3. Load model from downloaded directory
        let container = try await loadModelContainer(hub: Self.hubApi, directory: destDir) { _ in }

        lock.lock()
        self.container = container
        lock.unlock()

        state = .ready
        print("[ModelManager] Model ready ✓")
    }

    /// Quick HEAD request to huggingface.co with 10s timeout.
    private static func checkHuggingFaceReachable(session: URLSession) async -> Bool {
        guard let url = URL(string: "https://huggingface.co/api/models") else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 10
        do {
            let (_, response) = try await session.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            print("[ModelManager] HF API status: \(status)")
            return (200..<400).contains(status)
        } catch {
            print("[ModelManager] HF reachability check failed: \(error.localizedDescription)")
            return false
        }
    }

    public func pauseDownload() {
        // Hub API doesn't expose pause; no-op for now
    }

    public func deleteModel() throws {
        lock.lock()
        container = nil
        lock.unlock()
        state = .notDownloaded
        // Hub caches in ~/Library/Caches/huggingface; clearing requires file ops
    }

    public func generate(messages: [ChatMessage], maxTokens: Int, temperature: Double, imageResizeSize: Int?) async throws -> String {
        guard let container else {
            throw ModelManagerError.modelNotReady
        }

        // Aggressively limit GPU cache to 20 MB — forces MLX to release old KV/activation buffers between calls.
        // Without this, memory accumulates across calls and jetsam kills the app after ~6 inferences.
        MLX.GPU.set(cacheLimit: 20 * 1024 * 1024)

        let imageCount = messages.reduce(0) { $0 + $1.images.count }
        let resizeStr = imageResizeSize.map(String.init) ?? "nil"
        print("[ModelManager] generate() start — \(messages.count) msgs, \(imageCount) images, maxTokens=\(maxTokens), temp=\(temperature), imageResize=\(resizeStr)")
        let startTime = CFAbsoluteTimeGetCurrent()
        defer {
            let elapsed = CFAbsoluteTimeGetCurrent() - startTime
            print("[ModelManager] generate() done — \(String(format: "%.1f", elapsed))s")
        }

        // Build Chat.Message array preserving system + user roles
        let chatMessages: [Chat.Message] = messages.map { msg in
            let role: Chat.Message.Role = switch msg.role {
            case .system: .system
            case .user: .user
            case .assistant: .assistant
            }
            let images: [UserInput.Image] = msg.images.compactMap { data in
                guard let ciImage = CIImage(data: data) else { return nil }
                return .ciImage(ciImage)
            }
            return Chat.Message(role: role, content: msg.text, images: images)
        }

        let processing: UserInput.Processing
        if let size = imageResizeSize {
            processing = .init(resize: CGSize(width: size, height: size))
        } else {
            processing = .init()
        }

        // Build UserInput directly — bypasses ChatSession which drops system messages
        let userInput = UserInput(
            chat: chatMessages,
            processing: processing
        )

        let params = GenerateParameters(maxTokens: maxTokens, temperature: Float(temperature))

        let raw: String = try await container.perform { context in
            let input = try await context.processor.prepare(input: userInput)
            let result: GenerateResult = try MLXLMCommon.generate(
                input: input,
                parameters: params,
                context: context
            ) { (_: [Int]) in .more }
            return result.output
        }

        print("[ModelManager] generate returned \(raw.count) chars:\n\(raw)")
        // Defensive: strip any <think> blocks if model unexpectedly emits them
        return Self.stripThinkBlocks(raw)
    }

    /// Remove <think>...</think> reasoning blocks from model output.
    private static func stripThinkBlocks(_ text: String) -> String {
        text.replacingOccurrences(
            of: #"<think>[\s\S]*?</think>"#,
            with: "",
            options: .regularExpression
        ).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Cache Management

    /// MLX uses Caches/models/ (via defaultHubApi), NOT Documents/huggingface/.
    public static var cacheBaseURL: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appending(component: "models")
    }

    /// Returns (modelId, sizeBytes) for each cached model directory.
    public static func cachedModels() -> [(id: String, bytes: Int64)] {
        let fm = FileManager.default
        let base = cacheBaseURL
        guard fm.fileExists(atPath: base.path),
              let orgs = try? fm.contentsOfDirectory(atPath: base.path) else { return [] }

        var results: [(String, Int64)] = []
        for org in orgs {
            let orgURL = base.appending(component: org)
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: orgURL.path, isDirectory: &isDir), isDir.boolValue else { continue }
            guard let repos = try? fm.contentsOfDirectory(atPath: orgURL.path) else { continue }
            for repo in repos {
                let repoURL = orgURL.appending(component: repo)
                guard fm.fileExists(atPath: repoURL.path, isDirectory: &isDir), isDir.boolValue else { continue }
                let size = Self.directorySize(repoURL)
                if size > 0 {
                    results.append(("\(org)/\(repo)", size))
                }
            }
        }
        return results
    }

    /// Total bytes used by all cached models.
    public static func totalCacheBytes() -> Int64 {
        cachedModels().reduce(0) { $0 + $1.bytes }
    }

    /// Delete all cached models EXCEPT the one with `keepModelId`.
    /// Returns bytes freed.
    @discardableResult
    public static func purgeOtherModels(keeping keepModelId: String) -> Int64 {
        let fm = FileManager.default
        var freed: Int64 = 0
        for (id, bytes) in cachedModels() where id != keepModelId {
            let parts = id.split(separator: "/")
            guard parts.count == 2 else { continue }
            let url = cacheBaseURL
                .appending(component: String(parts[0]))
                .appending(component: String(parts[1]))
            try? fm.removeItem(at: url)
            freed += bytes
        }
        return freed
    }

    /// Scan all known cache directories and return total bytes used.
    /// Checks both Caches/models/ (MLX) and Documents/huggingface/ (Hub default).
    public static func totalAppCacheInfo() -> [(label: String, bytes: Int64)] {
        let fm = FileManager.default
        var entries: [(String, Int64)] = []

        // MLX model cache (Caches/models/)
        let mlxCache = cacheBaseURL
        if fm.fileExists(atPath: mlxCache.path) {
            entries.append(("Caches/models", directorySize(mlxCache)))
        }

        // Hub default cache (Documents/huggingface/)
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let hubCache = docs.appending(component: "huggingface")
        if fm.fileExists(atPath: hubCache.path) {
            entries.append(("Documents/huggingface", directorySize(hubCache)))
        }

        // General Caches/ size (minus models/)
        let cachesDir = fm.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let totalCaches = directorySize(cachesDir)
        let modelsSize = entries.first(where: { $0.0 == "Caches/models" })?.1 ?? 0
        let otherCaches = totalCaches - modelsSize
        if otherCaches > 0 {
            entries.append(("Caches/other", otherCaches))
        }

        // tmp/
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
        let tmpSize = directorySize(tmp)
        if tmpSize > 0 {
            entries.append(("tmp", tmpSize))
        }

        return entries
    }

    private static func directorySize(_ url: URL) -> Int64 {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey], options: [.skipsHiddenFiles]) else { return 0 }
        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                total += Int64(size)
            }
        }
        return total
    }
}

public enum ModelManagerError: LocalizedError {
    case modelNotReady
    case invalidMessages
    case networkUnavailable
    case downloadFailed(filename: String, status: Int)

    public var errorDescription: String? {
        switch self {
        case .modelNotReady: "Model not downloaded or loaded"
        case .invalidMessages: "Messages must end with a user message"
        case .networkUnavailable: "Cannot reach huggingface.co — check WiFi/VPN and try again"
        case .downloadFailed(let filename, let status): "Download failed for \(filename) (HTTP \(status))"
        }
    }
}

/// Minimal Codable struct matching HF API /api/models/{id} response.
private struct HFSiblingsResponse: Codable {
    struct Sibling: Codable {
        let rfilename: String
    }
    let siblings: [Sibling]
}

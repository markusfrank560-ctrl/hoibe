import AVFoundation
import PhotosUI
import SwiftUI
import VLMPipeline

struct ContentView: View {
    private static let defaultConfig = PawProfilerConfig()

    @State private var profiler = CatProfiler(
        modelManager: ModelManager(
            modelId: defaultConfig.modelId
        ),
        frameExtractor: FrameExtractor()
    )

    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedVideoURL: URL?
    @State private var videoDuration: TimeInterval?
    @State private var profileMode: ProfileMode = .quick
    @State private var durationError: String?
    @State private var showDebugLog = false

    private var config: PawProfilerConfig { profileMode == .deep ? .deep() : .quick() }
    private var minDuration: TimeInterval { config.minVideoDuration }
    private var maxDuration: TimeInterval { config.maxVideoDuration }

    var body: some View {
        NavigationStack {
            Group {
                switch profiler.analysisState {
                case .idle:
                    idleView

                case .downloadingModel(let progress):
                    modelDownloadView(progress: progress)

                case .extractingFrames:
                    PipelineStageView(stage: "Extracting frames…", icon: "film")

                case .runningGate:
                    PipelineStageView(stage: "Checking for cat…", icon: "cat")

                case .gateRejected(let result):
                    gateRejectedView(result)

                case .runningAgent(let agent, let total, let name):
                    AgentProgressView(
                        currentAgent: agent,
                        totalAgents: total,
                        agentName: name
                    )

                case .runningCoordinator:
                    PipelineStageView(stage: "Building personality profile…", icon: "brain.head.profile")

                case .complete(let profile):
                    PersonaCardView(profile: profile)

                case .error(let message):
                    errorView(message)
                }
            }
            .safeAreaInset(edge: .bottom) {
                if profiler.analysisState != .idle && !profiler.debugLog.isEmpty {
                    debugLogPanel
                }
            }
            .navigationTitle("PawProfiler")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
    }

    // MARK: - Idle View

    private var idleView: some View {
        ScrollView {
            VStack(spacing: 24) {
                Image(systemName: "pawprint.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.orange)

                Text("Cat Behavior Profiling")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                // Video Picker
                PhotosPicker(
                    selection: $selectedItem,
                    matching: .videos
                ) {
                    Label(
                        selectedVideoURL != nil ? "Change Video" : "Select Cat Video",
                        systemImage: "video.badge.plus"
                    )
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.orange.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
                }
                .onChange(of: selectedItem) { _, newItem in
                    Task { await loadVideo(from: newItem) }
                }

                // Duration Info
                if let duration = videoDuration {
                    Label(
                        String(format: "Duration: %.0fs", duration),
                        systemImage: "clock"
                    )
                    .font(.subheadline)
                    .foregroundStyle(isDurationValid ? Color.secondary : Color.red)
                }

                if let error = durationError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }

                // Mode Picker
                VStack(spacing: 8) {
                    Text("Analysis Mode")
                        .font(.caption)
                        .foregroundStyle(.tertiary)

                    Picker("Mode", selection: $profileMode) {
                        Text("Quick").tag(ProfileMode.quick)
                        Text("Deep").tag(ProfileMode.deep)
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 200)
                }

                // Analyze Button
                Button {
                    guard let url = selectedVideoURL else { return }
                    Task { await startAnalysis(url: url) }
                } label: {
                    Label("Analyze", systemImage: "sparkles")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(canAnalyze ? .orange : .gray.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(canAnalyze ? .white : .secondary)
                }
                .disabled(!canAnalyze)

                // Mode explanation
                Group {
                    if profileMode == .quick {
                        Text("Quick: ~2 min · 1 window per agent")
                    } else {
                        Text("Deep: ~5 min · 3 windows per agent · more nuance")
                    }
                }
                .font(.caption)
                .foregroundStyle(.tertiary)
            }
            .padding()
        }
    }

    // MARK: - Gate Rejected

    private func gateRejectedView(_ result: CatGateResult) -> some View {
        VStack {
            GateRejectedView(result: result)

            Button("Try Another Video") {
                profiler.cancel()
                selectedItem = nil
                selectedVideoURL = nil
                videoDuration = nil
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .padding()
        }
    }

    // MARK: - Error View

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.red)

            Text("Analysis Failed")
                .font(.title2.bold())

            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Button("Try Again") {
                profiler.cancel()
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
        }
        .padding()
    }

    // MARK: - Model Download View

    private func modelDownloadView(progress: Double) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 48))
                .foregroundStyle(.orange)
                .symbolEffect(.pulse)

            Text("Downloading Model…")
                .font(.title2.bold())

            ProgressView(value: progress)
                .tint(.orange)
                .padding(.horizontal, 40)

            Text("\(Int(progress * 100))%")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("Qwen3-VL 4B (≈2.5 GB)")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding()
    }

    // MARK: - Debug Log Panel

    private var debugLogPanel: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation { showDebugLog.toggle() }
            } label: {
                HStack {
                    Image(systemName: "ladybug")
                        .font(.caption)
                    Text(profiler.debugLog.last?.message ?? "")
                        .font(.caption2)
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: showDebugLog ? "chevron.down" : "chevron.up")
                        .font(.caption2)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
            }
            .buttonStyle(.plain)

            if showDebugLog {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            ForEach(profiler.debugLog) { entry in
                                HStack(alignment: .top, spacing: 6) {
                                    Text(entry.elapsed)
                                        .font(.system(.caption2, design: .monospaced))
                                        .foregroundStyle(.tertiary)
                                        .frame(width: 44, alignment: .trailing)
                                    Text(entry.message)
                                        .font(.system(.caption2, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                }
                                .id(entry.id)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                    }
                    .frame(maxHeight: 160)
                    .background(.ultraThinMaterial)
                    .onChange(of: profiler.debugLog.count) { _, _ in
                        if let last = profiler.debugLog.last {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Logic

    private var isDurationValid: Bool {
        guard let duration = videoDuration else { return false }
        return duration >= minDuration && duration <= maxDuration
    }

    private var canAnalyze: Bool {
        selectedVideoURL != nil && isDurationValid
    }

    private func loadVideo(from item: PhotosPickerItem?) async {
        guard let item else { return }
        durationError = nil
        selectedVideoURL = nil
        videoDuration = nil

        guard let data = try? await item.loadTransferable(type: VideoTransferable.self) else {
            durationError = "Could not load the selected video."
            return
        }

        let url = data.url
        let asset = AVURLAsset(url: url)
        let duration = try? await asset.load(.duration)
        let seconds = duration.map { CMTimeGetSeconds($0) } ?? 0

        selectedVideoURL = url
        videoDuration = seconds

        if seconds < minDuration {
            durationError = "Video is too short (min \(Int(minDuration))s)."
        } else if seconds > maxDuration {
            durationError = "Video is too long (max \(Int(maxDuration))s)."
        }
    }

    private func startAnalysis(url: URL) async {
        do {
            _ = try await profiler.analyze(videoURL: url, mode: profileMode)
        } catch {
            // State is set by CatProfiler
        }
    }
}

// MARK: - Video Transferable

struct VideoTransferable: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { video in
            SentTransferredFile(video.url)
        } importing: { received in
            let tempDir = FileManager.default.temporaryDirectory
            let dest = tempDir.appendingPathComponent(
                UUID().uuidString + "." + (received.file.pathExtension.isEmpty ? "mov" : received.file.pathExtension)
            )
            if FileManager.default.fileExists(atPath: dest.path) {
                try FileManager.default.removeItem(at: dest)
            }
            try FileManager.default.copyItem(at: received.file, to: dest)
            return VideoTransferable(url: dest)
        }
    }
}

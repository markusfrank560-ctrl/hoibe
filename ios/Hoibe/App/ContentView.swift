import SwiftUI
import PhotosUI
#if os(iOS)
import AVFoundation
import UIKit
#endif

struct ContentView: View {
    @StateObject private var viewModel = ContentViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                headerSection

                switch viewModel.screenState {
                case .downloadNeeded:
                    downloadSection
                case .downloading:
                    downloadProgressSection
                case .ready:
                    videoInputSection
                case .analyzing:
                    analysisProgressSection
                case .result(let result):
                    resultSection(result)
                case .error(let message):
                    errorSection(message)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("")
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(spacing: 4) {
            Text("🍺 Hoibe")
                .font(.largeTitle.bold())
            Text("Erster Schluck Erkennung")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var downloadSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 48))
                .foregroundStyle(.blue)

            Text("Modell herunterladen")
                .font(.headline)

            Text("~2.5 GB – nur über WLAN")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button("Download starten") {
                Task { await viewModel.startDownload() }
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var downloadProgressSection: some View {
        VStack(spacing: 12) {
            ProgressView(value: viewModel.downloadProgress)
                .progressViewStyle(.linear)

            Text("\(Int(viewModel.downloadProgress * 100))%")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)

            Text("Modell wird geladen…")
                .font(.subheadline)
        }
    }

    private var videoInputSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 36))
                .foregroundStyle(.green)

            Text("Bereit zur Analyse")
                .font(.headline)

            HStack(spacing: 16) {
                #if os(iOS)
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button {
                        Task { await viewModel.requestCameraAndShow() }
                    } label: {
                        Label("Aufnehmen", systemImage: "camera.fill")
                    }
                    .buttonStyle(.borderedProminent)
                }
                #endif

                PhotosPicker(
                    selection: $viewModel.selectedVideo,
                    matching: .videos
                ) {
                    Label("Bibliothek", systemImage: "photo.on.rectangle")
                }
                .buttonStyle(.bordered)
            }
        }
        #if os(iOS)
        .fullScreenCover(isPresented: $viewModel.showCamera) {
            CameraView(videoURL: $viewModel.capturedVideoURL)
        }
        #else
        .sheet(isPresented: $viewModel.showCamera) {
            CameraView(videoURL: $viewModel.capturedVideoURL)
        }
        #endif
        .onChange(of: viewModel.capturedVideoURL) {
            if let url = viewModel.capturedVideoURL {
                Task { await viewModel.analyze(videoURL: url) }
            }
        }
        .onChange(of: viewModel.selectedVideo) {
            Task { await viewModel.handlePickedVideo() }
        }
    }

    private var analysisProgressSection: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)

            Text(viewModel.analysisStatusText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private func resultSection(_ result: AnalysisResult) -> some View {
        VStack(spacing: 16) {
            Image(systemName: result.firstSipDetected ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(result.firstSipDetected ? .green : .red)

            Text(result.firstSipDetected ? "Erster Schluck erkannt!" : "Kein erster Schluck")
                .font(.title2.bold())

            Text("Konfidenz: \(Int(result.confidence * 100))%")
                .font(.headline.monospacedDigit())

            if !result.reasonShort.isEmpty {
                Text(result.reasonShort)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button("Neues Video") {
                viewModel.reset()
            }
            .buttonStyle(.bordered)
            .padding(.top)
        }
    }

    private func errorSection(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.orange)

            Text("Fehler")
                .font(.headline)

            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Erneut versuchen") {
                viewModel.reset()
            }
            .buttonStyle(.bordered)
        }
    }
}

// MARK: - ViewModel

@MainActor
final class ContentViewModel: ObservableObject {

    enum ScreenState {
        case downloadNeeded
        case downloading
        case ready
        case analyzing
        case result(AnalysisResult)
        case error(String)
    }

    @Published var screenState: ScreenState = .downloadNeeded
    @Published var downloadProgress: Double = 0
    @Published var analysisStatusText: String = ""
    @Published var showCamera = false
    @Published var capturedVideoURL: URL?
    @Published var selectedVideo: PhotosPickerItem?

    private let modelManager = ModelManager()
    private lazy var sipDetector = SipDetector(modelManager: modelManager)

    init() {
        // Check cache on next run loop (async)
        Task { await checkCachedModel() }
    }

    func checkCachedModel() async {
        if await modelManager.tryLoadCached() {
            screenState = .ready
        }
    }

    func startDownload() async {
        screenState = .downloading

        #if os(iOS)
        UIApplication.shared.isIdleTimerDisabled = true
        #endif

        modelManager.onProgress = { [weak self] frac in
            Task { @MainActor in
                self?.downloadProgress = frac
            }
        }
        do {
            try await modelManager.startDownload(allowCellular: false)
            screenState = .ready
        } catch {
            screenState = .error("Download fehlgeschlagen: \(error.localizedDescription)")
        }

        #if os(iOS)
        UIApplication.shared.isIdleTimerDisabled = false
        #endif
    }

    func analyze(videoURL: URL) async {
        screenState = .analyzing
        analysisStatusText = "Frames werden extrahiert…"

        // Observe analysis state changes
        let observation = Task { [weak self] in
            guard let self else { return }
            for await state in self.sipDetector.$analysisState.values {
                await MainActor.run {
                    self.updateStatusText(state)
                }
            }
        }

        do {
            let result = try await sipDetector.analyze(videoURL: videoURL)
            screenState = .result(result)
        } catch {
            screenState = .error("Analyse fehlgeschlagen: \(error.localizedDescription)")
        }

        observation.cancel()
    }

    func handlePickedVideo() async {
        guard let item = selectedVideo else { return }
        guard let data = try? await item.loadTransferable(type: VideoTransferable.self) else {
            screenState = .error("Video konnte nicht geladen werden")
            return
        }
        await analyze(videoURL: data.url)
    }

    func reset() {
        screenState = .ready
        capturedVideoURL = nil
        selectedVideo = nil
    }

    #if os(iOS)
    func requestCameraAndShow() async {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            showCamera = true
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            if granted { showCamera = true }
        default:
            break
        }
    }
    #endif

    private func updateStatusText(_ state: AnalysisState) {
        switch state {
        case .idle: analysisStatusText = ""
        case .validating: analysisStatusText = "Video wird validiert…"
        case .extractingFrames: analysisStatusText = "Frames werden extrahiert…"
        case .runningGate(let vote, let total): analysisStatusText = "Gate: Abstimmung \(vote)/\(total)…"
        case .runningWindows(let window, let total): analysisStatusText = "Analyse: Fenster \(window)/\(total)…"
        case .complete: analysisStatusText = "Fertig!"
        case .error(let msg): analysisStatusText = "Fehler: \(msg)"
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
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("mov")
            try FileManager.default.copyItem(at: received.file, to: tempURL)
            return Self(url: tempURL)
        }
    }
}

#Preview {
    ContentView()
}

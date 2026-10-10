import SwiftUI
import SwiftData
import AVFoundation
import CoreImage

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Item.title) private var items: [Item]
    @ObservedObject private var audioManager = AudioManager.shared
    @State private var isImporting = false

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView {
                HomeView(items: items, onPlay: playSong, onImportTapped: { isImporting = true })
                    .tabItem { Label("Home", systemImage: "house.fill") }

                SearchView(items: items, onPlay: playSong)
                    .tabItem { Label("Search", systemImage: "magnifyingglass") }

                LibraryView(items: items, onPlay: playSong, onImportTapped: { isImporting = true })
                    .tabItem { Label("Library", systemImage: "music.note.list") }
            }

            if audioManager.currentItem != nil {
                MiniPlayerView(audioManager: audioManager)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 60)
            }
        }
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.audio],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                for url in urls {
                    importSong(from: url)
                }
            case .failure(let error):
                print("Import failed: \(error)")
            }
        }
    }

    private func playSong(_ item: Item) {
        item.lastPlayedDate = Date()
        item.playCount += 1
        try? modelContext.save()
        audioManager.setPlaylist(items)
        audioManager.play(item)
    }

    private func importSong(from sourceURL: URL) {
        let didStartAccessing = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing { sourceURL.stopAccessingSecurityScopedResource() }
        }

        let fileName = sourceURL.lastPathComponent
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let destinationURL = documentsURL.appendingPathComponent(fileName)

        do {
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)

            let metadata = extractMetadata(from: destinationURL)
            let titleFromFile = sourceURL.deletingPathExtension().lastPathComponent

            let newSong = Item(
                title: metadata.title ?? titleFromFile,
                artist: metadata.artist ?? "Unknown Artist",
                album: metadata.album ?? "Unknown Album",
                fileName: fileName,
                artworkData: metadata.artworkData
            )
            modelContext.insert(newSong)
        } catch {
            print("Copy failed: \(error)")
        }
    }

    private struct ExtractedMetadata {
        var title: String?
        var artist: String?
        var album: String?
        var artworkData: Data?
    }

    private func extractMetadata(from url: URL) -> ExtractedMetadata {
        let asset = AVAsset(url: url)
        var result = ExtractedMetadata()
        let allMetadata = asset.commonMetadata + asset.metadata

        for item in allMetadata {
            guard let key = item.commonKey else { continue }
            switch key {
            case .commonKeyTitle:
                if result.title == nil { result.title = item.value as? String }
            case .commonKeyArtist:
                if result.artist == nil { result.artist = item.value as? String }
            case .commonKeyAlbumName:
                if result.album == nil { result.album = item.value as? String }
            case .commonKeyArtwork:
                if result.artworkData == nil { result.artworkData = item.value as? Data }
            default:
                break
            }
        }
        return result
    }
}

struct HomeView: View {
    let items: [Item]
    let onPlay: (Item) -> Void
    let onImportTapped: () -> Void

    private var recentlyPlayed: [Item] {
        Array(items.filter { $0.lastPlayedDate != nil }
            .sorted { $0.lastPlayedDate! > $1.lastPlayedDate! }
            .prefix(10))
    }

    private var mostPlayed: [Item] {
        Array(items.filter { $0.playCount > 0 }
            .sorted { $0.playCount > $1.playCount }
            .prefix(10))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    if items.isEmpty {
                        emptyState
                    } else {
                        shuffleCard

                        if !recentlyPlayed.isEmpty {
                            sectionHeader("Recently Played")
                            horizontalRow(recentlyPlayed)
                        }

                        if !mostPlayed.isEmpty {
                            sectionHeader("Most Played")
                            horizontalRow(mostPlayed)
                        }
                    }
                }
                .padding(.top, 12)
                .padding(.bottom, 100)
            }
            .navigationTitle("Home")
        }
    }

    private var shuffleCard: some View {
        Button {
            if let random = items.randomElement() {
                onPlay(random)
            }
        } label: {
            HStack(spacing: 16) {
                Image(systemName: "shuffle")
                    .font(.system(size: 28, weight: .bold))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Shuffle All")
                        .font(.title3)
                        .fontWeight(.bold)
                    Text("\(items.count) songs")
                        .font(.subheadline)
                        .opacity(0.85)
                }
                Spacer()
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 34))
            }
            .foregroundStyle(.white)
            .padding(20)
            .background(
                LinearGradient(colors: [.purple, .pink, .orange], startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .padding(.horizontal)
        }
        .buttonStyle(.plain)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 22, weight: .bold, design: .rounded))
            .padding(.horizontal)
    }

    private func horizontalRow(_ songs: [Item]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(songs) { song in
                    Button {
                        onPlay(song)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            AlbumArtView(artworkData: song.artworkData, size: 120)
                            Text(song.title)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .lineLimit(1)
                                .foregroundStyle(.primary)
                            Text(song.artist)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        .frame(width: 120)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "music.note.house.fill")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Welcome to Cordelia")
                .font(.headline)
            Text("Add some songs from the Library tab to get started")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Import Songs", action: onImportTapped)
                .buttonStyle(.borderedProminent)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
        .padding(.horizontal, 32)
    }
}

struct SearchView: View {
    let items: [Item]
    let onPlay: (Item) -> Void
    @State private var searchText = ""

    private var filtered: [Item] {
        if searchText.isEmpty { return [] }
        return items.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.artist.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if searchText.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary)
                        Text("Search your songs")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filtered.isEmpty {
                    Text("No results for \"\(searchText)\"")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(filtered) { item in
                        HStack(spacing: 12) {
                            AlbumArtView(artworkData: item.artworkData, size: 44)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title).font(.headline)
                                Text(item.artist).font(.subheadline).foregroundStyle(.secondary)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { onPlay(item) }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Search")
            .searchable(text: $searchText, prompt: "Songs, artists")
        }
    }
}

struct LibraryView: View {
    let items: [Item]
    let onPlay: (Item) -> Void
    let onImportTapped: () -> Void
    @ObservedObject private var audioManager = AudioManager.shared

    var body: some View {
        NavigationStack {
            Group {
                if items.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("No songs yet")
                            .font(.headline)
                        Text("Tap + to add music from your files")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(items) { item in
                        HStack(spacing: 12) {
                            AlbumArtView(artworkData: item.artworkData, size: 50)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title).font(.headline).lineLimit(1)
                                Text(item.artist).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                            }
                            Spacer()
                            if audioManager.currentItem?.fileName == item.fileName {
                                if audioManager.isPlaying {
                                    EqualizerBarsView(color: .blue)
                                } else {
                                    Image(systemName: "pause.fill")
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                        .onTapGesture { onPlay(item) }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Library")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: onImportTapped) {
                        Image(systemName: "plus")
                    }
                }
            }
        }
    }
}

struct AlbumArtView: View {
    let artworkData: Data?
    let size: CGFloat

    var body: some View {
        if let data = artworkData, let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.18))
        } else {
            RoundedRectangle(cornerRadius: size * 0.18)
                .fill(LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: size, height: size)
                .overlay(
                    Image(systemName: "music.note")
                        .foregroundStyle(.white)
                        .font(.system(size: size * 0.4))
                )
        }
    }
}

struct EqualizerBarsView: View {
    @State private var animate = false
    var color: Color = .blue

    var body: some View {
        HStack(alignment: .bottom, spacing: 3) {
            bar(low: 0.3, high: 1.0, delay: 0)
            bar(low: 0.4, high: 0.7, delay: 0.15)
            bar(low: 0.25, high: 0.9, delay: 0.3)
        }
        .frame(width: 20, height: 16)
        .onAppear { animate = true }
    }

    private func bar(low: CGFloat, high: CGFloat, delay: Double) -> some View {
        RoundedRectangle(cornerRadius: 1.5)
            .fill(color)
            .frame(width: 3, height: animate ? 16 * high : 16 * low)
            .animation(
                .easeInOut(duration: 0.5)
                    .repeatForever(autoreverses: true)
                    .delay(delay),
                value: animate
            )
    }
}

struct MiniPlayerView: View {
    @ObservedObject var audioManager: AudioManager
    @State private var isDragging = false
    @State private var dragValue: Double = 0
    @State private var showNowPlaying = false

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 16) {
                HStack(spacing: 16) {
                    AlbumArtView(artworkData: audioManager.currentItem?.artworkData, size: 46)
                        .shadow(radius: 4)

                    VStack(alignment: .leading) {
                        Text(audioManager.currentItem?.title ?? "")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .lineLimit(1)
                        Text(audioManager.currentItem?.artist ?? "")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { showNowPlaying = true }

                Spacer()
                Button(action: { audioManager.playPrevious() }) {
                    Image(systemName: "backward.fill")
                }
                Button(action: { audioManager.togglePlayPause() }) {
                    Image(systemName: audioManager.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title2)
                }
                Button(action: { audioManager.playNext() }) {
                    Image(systemName: "forward.fill")
                }
            }
            .font(.title3)

            VStack(spacing: 2) {
                Slider(
                    value: Binding(
                        get: { isDragging ? dragValue : audioManager.currentTime },
                        set: { newValue in dragValue = newValue }
                    ),
                    in: 0...(max(audioManager.duration, 1)),
                    onEditingChanged: { editing in
                        if editing {
                            isDragging = true
                            dragValue = audioManager.currentTime
                        } else {
                            audioManager.seek(to: dragValue)
                            isDragging = false
                        }
                    }
                )

                HStack {
                    Text(formatTime(isDragging ? dragValue : audioManager.currentTime))
                    Spacer()
                    Text(formatTime(audioManager.duration))
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.25), radius: 12, y: 6)
        .sheet(isPresented: $showNowPlaying) {
            NowPlayingView(audioManager: audioManager)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        guard time.isFinite, !time.isNaN else { return "0:00" }
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct NowPlayingView: View {
    @ObservedObject var audioManager: AudioManager
    @State private var isDragging = false
    @State private var dragValue: Double = 0
    @State private var backgroundColor: Color = .purple

    var body: some View {
        VStack(spacing: 28) {
            Spacer().frame(height: 8)

            AlbumArtView(artworkData: audioManager.currentItem?.artworkData, size: 300)
                .shadow(color: .black.opacity(0.3), radius: 20, y: 10)

            VStack(spacing: 4) {
                Text(audioManager.currentItem?.title ?? "")
                    .font(.title2)
                    .fontWeight(.bold)
                    .lineLimit(1)
                Text(audioManager.currentItem?.artist ?? "")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 24)

            VStack(spacing: 4) {
                Slider(
                    value: Binding(
                        get: { isDragging ? dragValue : audioManager.currentTime },
                        set: { newValue in dragValue = newValue }
                    ),
                    in: 0...(max(audioManager.duration, 1)),
                    onEditingChanged: { editing in
                        if editing {
                            isDragging = true
                            dragValue = audioManager.currentTime
                        } else {
                            audioManager.seek(to: dragValue)
                            isDragging = false
                        }
                    }
                )
                HStack {
                    Text(formatTime(isDragging ? dragValue : audioManager.currentTime))
                    Spacer()
                    Text(formatTime(audioManager.duration))
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 24)

            HStack(spacing: 50) {
                Button(action: { audioManager.playPrevious() }) {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 28))
                }
                Button(action: { audioManager.togglePlayPause() }) {
                    Image(systemName: audioManager.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 64))
                }
                Button(action: { audioManager.playNext() }) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 28))
                }
            }
            .foregroundStyle(.primary)

            HStack(spacing: 40) {
                Button(action: { audioManager.cycleRepeatMode() }) {
                    Image(systemName: audioManager.repeatMode == .one ? "repeat.1" : "repeat")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(audioManager.repeatMode == .off ? Color.secondary : Color.blue)
                }

                Menu {
                    Button {
                        audioManager.hapticMode = .off
                    } label: {
                        if audioManager.hapticMode == .off {
                            Label("Off", systemImage: "checkmark")
                        } else {
                            Text("Off")
                        }
                    }
                    Button {
                        audioManager.hapticMode = .appleMusicHaptics
                    } label: {
                        if audioManager.hapticMode == .appleMusicHaptics {
                            Label("Apple Music Haptics", systemImage: "checkmark")
                        } else {
                            Text("Apple Music Haptics")
                        }
                    }
                    Button {
                        audioManager.hapticMode = .customBeatHaptics
                    } label: {
                        if audioManager.hapticMode == .customBeatHaptics {
                            Label("Custom Beat Haptics", systemImage: "checkmark")
                        } else {
                            Text("Custom Beat Haptics")
                        }
                    }
                } label: {
                    Image(systemName: hapticIconName)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(audioManager.hapticMode == .off ? Color.secondary : Color.blue)
                }
            }
            .padding(.top, 2)

            Spacer()
        }
        .padding(.top, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(colors: [backgroundColor.opacity(0.55), Color(.systemBackground)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        )
        .animation(.easeInOut(duration: 0.6), value: backgroundColor)
        .onAppear { updateBackgroundColor() }
        .onChange(of: audioManager.currentItem?.fileName) { _, _ in
            updateBackgroundColor()
        }
    }

    private var hapticIconName: String {
        switch audioManager.hapticMode {
        case .off: return "hand.tap"
        case .appleMusicHaptics: return "waveform"
        case .customBeatHaptics: return "hand.tap.fill"
        }
    }

    private func updateBackgroundColor() {
        if let data = audioManager.currentItem?.artworkData, let uiImage = UIImage(data: data) {
            backgroundColor = uiImage.dominantColor()
        } else {
            backgroundColor = .purple
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        guard time.isFinite, !time.isNaN else { return "0:00" }
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

extension UIImage {
    func dominantColor() -> Color {
        guard let inputImage = CIImage(image: self) else { return .purple }
        let extentVector = CIVector(
            x: inputImage.extent.origin.x,
            y: inputImage.extent.origin.y,
            z: inputImage.extent.size.width,
            w: inputImage.extent.size.height
        )

        guard let filter = CIFilter(name: "CIAreaAverage", parameters: [
            kCIInputImageKey: inputImage,
            kCIInputExtentKey: extentVector
        ]), let outputImage = filter.outputImage else {
            return .purple
        }

        var bitmap = [UInt8](repeating: 0, count: 4)
        let context = CIContext(options: [.workingColorSpace: kCFNull as Any])
        context.render(
            outputImage,
            toBitmap: &bitmap,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: nil
        )

        return Color(
            red: Double(bitmap[0]) / 255,
            green: Double(bitmap[1]) / 255,
            blue: Double(bitmap[2]) / 255
        )
    }
}

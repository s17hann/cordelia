import Foundation
import AVFoundation
import MediaPlayer
import CoreHaptics
import Combine
import UIKit

enum RepeatMode {
    case off
    case all
    case one
}

enum HapticMode {
    case off
    case appleMusicHaptics
    case customBeatHaptics
}

class AudioManager: NSObject, ObservableObject, AVAudioPlayerDelegate {
    static let shared = AudioManager()

    private var player: AVAudioPlayer?
    private var progressTimer: Timer?
    private var hapticTimer: Timer?
    private var hapticEngine: CHHapticEngine?
    private var previousLevel: Float = 0
    private var currentISRC: String?
    private var spotifyAccessToken: String?
    private var spotifyTokenExpiry: Date = .distantPast
    private var playlist: [Item] = []

    @Published var currentItem: Item?
    @Published var isPlaying: Bool = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var repeatMode: RepeatMode = .off
    @Published var hapticMode: HapticMode = .off {
        didSet {
            switch hapticMode {
            case .off, .appleMusicHaptics:
                stopHapticTimer()
            case .customBeatHaptics:
                startHapticEngine()
                if isPlaying { startHapticTimer() }
            }
        }
    }

    override init() {
        super.init()
        configureAudioSession()
        setupRemoteCommandCenter()
    }

    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Audio session setup failed: \(error)")
        }
    }

    func setPlaylist(_ items: [Item]) {
        playlist = items
    }

    func cycleRepeatMode() {
        switch repeatMode {
        case .off: repeatMode = .all
        case .all: repeatMode = .one
        case .one: repeatMode = .off
        }
    }

    func play(_ item: Item) {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsURL.appendingPathComponent(item.fileName)

        do {
            player = try AVAudioPlayer(contentsOf: fileURL)
            player?.delegate = self
            player?.isMeteringEnabled = true
            player?.play()
            currentItem = item
            isPlaying = true
            duration = player?.duration ?? 0
            currentTime = 0
            currentISRC = item.isrc

            if item.isrc == nil {
                fetchISRC(for: item)
            }

            startProgressTimer()
            updateNowPlayingInfo()
            if hapticMode == .customBeatHaptics { startHapticTimer() }
        } catch {
            print("Playback failed: \(error)")
        }
    }

    func togglePlayPause() {
        guard let player = player else { return }
        if isPlaying {
            player.pause()
            stopProgressTimer()
            stopHapticTimer()
        } else {
            player.play()
            startProgressTimer()
            if hapticMode == .customBeatHaptics { startHapticTimer() }
        }
        isPlaying.toggle()
        updateNowPlayingInfo()
    }

    func seek(to time: TimeInterval) {
        guard let player = player else { return }
        player.currentTime = time
        currentTime = time
        updateNowPlayingInfo()
    }

    func playNext() {
        guard let current = currentItem,
              let index = playlist.firstIndex(where: { $0.fileName == current.fileName }),
              index + 1 < playlist.count else { return }
        play(playlist[index + 1])
    }

    func playPrevious() {
        guard let current = currentItem,
              let index = playlist.firstIndex(where: { $0.fileName == current.fileName }),
              index - 1 >= 0 else { return }
        play(playlist[index - 1])
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.handleSongFinished()
        }
    }

    private func handleSongFinished() {
        switch repeatMode {
        case .one:
            seek(to: 0)
            player?.play()
            isPlaying = true
            startProgressTimer()
            if hapticMode == .customBeatHaptics { startHapticTimer() }
            updateNowPlayingInfo()
        case .off, .all:
            guard let current = currentItem,
                  let index = playlist.firstIndex(where: { $0.fileName == current.fileName }) else {
                stopAtEnd()
                return
            }
            if index + 1 < playlist.count {
                play(playlist[index + 1])
            } else if repeatMode == .all, let first = playlist.first {
                play(first)
            } else {
                stopAtEnd()
            }
        }
    }

    private func stopAtEnd() {
        isPlaying = false
        stopProgressTimer()
        stopHapticTimer()
        updateNowPlayingInfo()
    }

    private func startProgressTimer() {
        stopProgressTimer()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self, let player = self.player else { return }
            self.currentTime = player.currentTime
        }
    }

    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }

    private func getSpotifyToken(completion: @escaping (String?) -> Void) {
        if let token = spotifyAccessToken, Date() < spotifyTokenExpiry {
            completion(token)
            return
        }

        guard let url = URL(string: "https://accounts.spotify.com/api/token") else {
            completion(nil)
            return
        }

        let clientID = Secrets.spotifyClientID.trimmingCharacters(in: .whitespacesAndNewlines)
        let clientSecret = Secrets.spotifyClientSecret.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let authData = "\(clientID):\(clientSecret)".data(using: .utf8) else {
            completion(nil)
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Basic \(authData.base64EncodedString())", forHTTPHeaderField: "Authorization")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = "grant_type=client_credentials".data(using: .utf8)

        URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            guard let data = data, error == nil else {
                print("Spotify token request failed: \(error?.localizedDescription ?? "Unknown")")
                completion(nil)
                return
            }
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let token = json["access_token"] as? String,
               let expiresIn = json["expires_in"] as? Double {
                self?.spotifyAccessToken = token
                self?.spotifyTokenExpiry = Date().addingTimeInterval(expiresIn - 60)
                completion(token)
            } else {
                print("Spotify token response unexpected: \(String(data: data, encoding: .utf8) ?? "")")
                completion(nil)
            }
        }.resume()
    }

    private func fetchISRC(for item: Item) {
        guard !Secrets.spotifyClientID.isEmpty, !Secrets.spotifyClientSecret.isEmpty else { return }

        var cleanTitle = item.title.components(separatedBy: " - ").first ?? item.title
        cleanTitle = cleanTitle.components(separatedBy: " (").first ?? cleanTitle
        cleanTitle = cleanTitle.components(separatedBy: " [").first ?? cleanTitle
        cleanTitle = cleanTitle.trimmingCharacters(in: .whitespacesAndNewlines)

        var cleanArtist = item.artist.components(separatedBy: " - ").first ?? item.artist
        cleanArtist = cleanArtist.trimmingCharacters(in: .whitespacesAndNewlines)

        var query = "track:\(cleanTitle)"
        if cleanArtist.lowercased() != "unknown artist" && !cleanArtist.isEmpty {
            query += " artist:\(cleanArtist)"
        }

        getSpotifyToken { [weak self] token in
            guard let self = self, let token = token else { return }

            guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                  let searchURL = URL(string: "https://api.spotify.com/v1/search?q=\(encodedQuery)&type=track&limit=1") else { return }

            var request = URLRequest(url: searchURL)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

            URLSession.shared.dataTask(with: request) { data, _, error in
                guard let data = data, error == nil else {
                    print("Spotify search failed: \(error?.localizedDescription ?? "Unknown")")
                    return
                }
                guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let tracks = json["tracks"] as? [String: Any],
                      let items = tracks["items"] as? [[String: Any]],
                      let first = items.first,
                      let externalIDs = first["external_ids"] as? [String: Any],
                      let isrc = externalIDs["isrc"] as? String else {
                    print("No Spotify match for \(cleanTitle)")
                    return
                }

                DispatchQueue.main.async {
                    item.isrc = isrc
                    guard self.currentItem?.fileName == item.fileName else { return }
                    self.currentISRC = isrc
                    self.updateNowPlayingInfo()
                }
            }.resume()
        }
    }

    private func startHapticEngine() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        if hapticEngine != nil { return }
        do {
            let engine = try CHHapticEngine()
            engine.resetHandler = { [weak self] in
                try? self?.hapticEngine?.start()
            }
            engine.stoppedHandler = { _ in }
            try engine.start()
            hapticEngine = engine
        } catch {
            print("Haptic engine failed to start: \(error)")
        }
    }

    private func startHapticTimer() {
        stopHapticTimer()
        previousLevel = 0
        hapticTimer = Timer.scheduledTimer(withTimeInterval: 0.06, repeats: true) { [weak self] _ in
            self?.sampleAudioForHaptics()
        }
    }

    private func stopHapticTimer() {
        hapticTimer?.invalidate()
        hapticTimer = nil
    }

    private func sampleAudioForHaptics() {
        guard hapticMode == .customBeatHaptics, let player = player, player.isPlaying else { return }

        player.updateMeters()
        let power = player.averagePower(forChannel: 0)

        let minDb: Float = -45
        let clamped = max(power, minDb)
        let level = (clamped - minDb) / (0 - minDb)

        if level - previousLevel > 0.12 && level > 0.35 {
            playHapticPulse(intensity: level)
        }
        previousLevel = level
    }

    private func playHapticPulse(intensity: Float) {
        guard let engine = hapticEngine else { return }
        let intensityParam = CHHapticEventParameter(parameterID: .hapticIntensity, value: min(max(intensity, 0.3), 1.0))
        let sharpnessParam = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
        let event = CHHapticEvent(eventType: .hapticTransient, parameters: [intensityParam, sharpnessParam], relativeTime: 0)
        do {
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let hapticPlayer = try engine.makePlayer(with: pattern)
            try hapticPlayer.start(atTime: CHHapticTimeImmediate)
        } catch {
            print("Haptic pulse failed: \(error)")
        }
    }

    private func updateNowPlayingInfo() {
        guard let item = currentItem else { return }

        var info = [String: Any]()
        info[MPMediaItemPropertyTitle] = item.title
        info[MPMediaItemPropertyArtist] = item.artist
        info[MPMediaItemPropertyAlbumTitle] = item.album
        info[MPNowPlayingInfoPropertyMediaType] = MPNowPlayingInfoMediaType.audio.rawValue
        info[MPNowPlayingInfoPropertyIsLiveStream] = false
        info[MPNowPlayingInfoPropertyDefaultPlaybackRate] = 1.0

        if let data = item.artworkData, let image = UIImage(data: data) {
            info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
        }

        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = player?.currentTime ?? 0
        info[MPMediaItemPropertyPlaybackDuration] = player?.duration ?? 0
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0

        if let isrc = currentISRC {
            info[MPNowPlayingInfoPropertyInternationalStandardRecordingCode] = isrc
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        MPNowPlayingInfoCenter.default().playbackState = isPlaying ? .playing : .paused
    }

    private func setupRemoteCommandCenter() {
        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.addTarget { [weak self] _ in
            guard let self = self, let player = self.player else { return .commandFailed }
            player.play()
            self.isPlaying = true
            self.startProgressTimer()
            if self.hapticMode == .customBeatHaptics { self.startHapticTimer() }
            self.updateNowPlayingInfo()
            return .success
        }

        commandCenter.pauseCommand.addTarget { [weak self] _ in
            guard let self = self, let player = self.player else { return .commandFailed }
            player.pause()
            self.isPlaying = false
            self.stopProgressTimer()
            self.stopHapticTimer()
            self.updateNowPlayingInfo()
            return .success
        }

        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            self?.playNext()
            return .success
        }

        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            self?.playPrevious()
            return .success
        }

        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let self = self, let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            self.seek(to: event.positionTime)
            return .success
        }
    }
}

# Cordelia

*Made by Shihan*

A SwiftUI music player for iPhone that plays songs from your own files, built as an experiment to bring **Apple Music Haptics** to a third-party app.

> **Status: work in progress.** The player works. Apple's system Music Haptics does **not** yet work for Cordelia (see [Music Haptics status](#music-haptics-status)). Contributions and ideas are welcome.

## Features

- Import your own audio files from the Files app
- Song library saved on the device with SwiftData
- Three tabs: Home, Search and Library
  - Home: Shuffle All, Recently Played, Most Played
  - Search: search by song title or artist
  - Library: full song list with a "now playing" equalizer indicator
- Mini player and a full Now Playing screen with seek bar
- Album art, with a background color taken from the artwork
- Repeat modes: off, repeat all, repeat one
- Lock Screen, Control Center and Dynamic Island controls
- Background audio playback
- Three haptic modes you can pick in the Now Playing screen:
  - **Off**
  - **Apple Music Haptics** (system-driven, experimental, see below)
  - **Custom Beat Haptics** (our own Core Haptics engine that reacts to the audio level)

## Music Haptics status

This is the main goal of the project, and it is not working yet.

**What is already set up, following Apple's documented steps:**

1. `MusicHapticsSupported = YES` in the app's Info.plist
2. The app publishes Now Playing info through `MPNowPlayingInfoCenter`
3. The track's ISRC is published with `MPNowPlayingInfoPropertyInternationalStandardRecordingCode`
4. Apple's `MAMusicHapticsManager` (MediaAccessibility framework) is imported

**What happens:**

- Music Haptics is turned on in Settings > Accessibility, and the same song (Billie Jean) gives haptics in the Apple Music app.
- When the same song plays in Cordelia, the Now Playing card in Control Center shows Music Haptics as **unavailable**, and no haptics are felt.
- The Now Playing dictionary was printed in the console and it contains the correct title, artist, album and ISRC.

**What has been ruled out so far:** device support (iPhone 14 Pro Max), internet connection, the global Music Haptics setting, the Info.plist key, and using two different ISRCs for the same song.

If you know how third-party apps get Music Haptics to activate, please open an issue or a pull request.

## Requirements

- Mac with a recent version of Xcode
- An iPhone for testing. The simulator has no haptics.
- Music Haptics itself needs an iPhone 12 or newer (not iPhone SE) with Music Haptics turned on in Settings > Accessibility

## Run it yourself

1. Clone the repo:
   ```
   git clone https://github.com/YOUR-USERNAME/Cordelia.git
   ```
2. Open `Cordelia.xcodeproj` in Xcode.
3. In **Signing & Capabilities**, choose your own Team and change the Bundle Identifier to something unique.
4. Plug in your iPhone, select it as the run target, and press Run.
5. Open the Library tab, tap **+**, and import some songs from your Files app.

### Optional: automatic ISRC lookup

`AudioManager.swift` can look up a song's ISRC using the Spotify Web API.

1. Create a free app at https://developer.spotify.com/dashboard
2. Put your own Client ID and Client Secret into the `spotifyClientID` and `spotifyClientSecret` constants in `AudioManager.swift`.
3. Never commit real credentials to a public repo.

At the moment, `play()` uses a hard-coded test ISRC for debugging instead of this lookup, so every song reports the same ISRC.

## Project structure

| File | What it does |
| --- | --- |
| `CordeliaApp.swift` | App entry point |
| `ContentView.swift` | Tabs, Home, Search, Library, mini player, Now Playing screen |
| `AudioManager.swift` | Playback, Now Playing info, remote controls, haptics, ISRC lookup |
| `Item.swift` | SwiftData model for a song |
| `Info.plist` | Background audio and `MusicHapticsSupported` |

## Roadmap

- [ ] Get Apple Music Haptics to activate for Cordelia
- [ ] Look up the real ISRC for each song instead of the test value
- [ ] Move API credentials out of the source code
- [ ] Playlists
- [ ] Queue view

## Disclaimer

Cordelia is an independent hobby project by Shihan. It is not affiliated with or endorsed by Apple or Spotify. Apple Music and Music Haptics are Apple trademarks. Spotify is a trademark of Spotify AB. Bring your own music files, and only use music you have the right to use.

## Author

Built by **Shihan**. I'm learning iOS development by building this app, and I'm sharing it as an ongoing project. Feedback, issues and pull requests are welcome.

## License

MIT License. Copyright (c) 2026 Shihan. See the [LICENSE](LICENSE) file for details.

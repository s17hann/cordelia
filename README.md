<h1 align="center">Cordelia</h1>

<p align="center">
  A local music player for iOS with Apple Music Haptics support.<br>
  Built with SwiftUI and SwiftData.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Swift-FA7343?style=flat&logo=swift&logoColor=white" alt="Swift">
  <img src="https://img.shields.io/badge/iOS-18+-000000?style=flat&logo=apple&logoColor=white" alt="iOS 18+">
  <img src="https://img.shields.io/badge/status-in%20progress-yellow?style=flat" alt="In progress">
</p>

---

## About

Cordelia plays music you import from your own files and lets you feel it through your iPhone's haptics. It works with iOS 18's Music Haptics feature and includes its own haptic engine for songs Apple doesn't cover.

## Features

- **Import your music** from the Files app, with title, artist, album and artwork read automatically
- **Home, Search and Library** tabs, with Recently Played and Most Played sections
- **Now Playing screen** with seek bar, repeat modes and a background color taken from the album art
- **Lock screen and Control Center** controls
- **Apple Music Haptics** support, using ISRC codes looked up automatically through the Spotify Web API
- **Custom haptics mode** that turns the audio's beat into vibration using Core Haptics

## Built with

Swift, SwiftUI, SwiftData, AVFoundation, MediaPlayer, Core Haptics

## Getting started

1. Clone this repo and open `Cordelia.xcodeproj` in Xcode.
2. Create a free app at developer.spotify.com/dashboard to get a Client ID and Client Secret.
3. Copy `Secrets.example.swift` into the `Cordelia` source folder, rename it to `Secrets.swift`, and add your keys.
4. Run on a real iPhone, since haptics don't work in the Simulator.

## Roadmap

- [ ] Playlists and queue editing
- [ ] Better song matching for ISRC lookup
- [ ] Unit tests

## Author

Made by Shihan Panwar

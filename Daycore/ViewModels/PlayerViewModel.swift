//
//  PlayerViewModel.swift
//  Daycore
//
//  Created by inugaminé on 2026/05/25.
//

import Foundation
import Combine
import MediaPlayer

/// プレーヤー画面の ViewModel
/// AudioEngineService と MusicLibraryService を橋渡しする
@MainActor
final class PlayerViewModel: ObservableObject {
    
    // MARK: - Services
    
    let audioEngine = AudioEngineService()
    var musicLibrary = MusicLibraryService()
    
    // MARK: - Published State
    
    @Published var currentTrack: Track?
    @Published var selectedPreset: AudioPreset = .daycore
    @Published var showingLibrary = false
    @Published var showingFileImporter = false
    @Published var isSeeking = false
    
    // スライダー用（シーク中はユーザーの操作値を保持）
    @Published var seekTime: TimeInterval = 0
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Computed Properties
    
    var isPlaying: Bool { audioEngine.isPlaying }
    var duration: TimeInterval { audioEngine.duration }
    
    var displayTime: TimeInterval {
        isSeeking ? seekTime : audioEngine.currentTime
    }
    
    var currentTimeFormatted: String {
        formatTime(displayTime)
    }
    
    var durationFormatted: String {
        formatTime(duration)
    }
    
    var progress: Double {
        guard duration > 0 else { return 0 }
        return displayTime / duration
    }
    
    // MARK: - Init
    
    init() {
        // AudioEngine の変更を購読して UI を更新
        audioEngine.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        
        musicLibrary.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        
        // 初期プリセット適用
        audioEngine.applyPreset(selectedPreset)
    }
    
    // MARK: - Playback
    
    func selectTrack(_ track: Track) {
        currentTrack = track
        audioEngine.loadTrack(track)
        audioEngine.applyPreset(selectedPreset)
        audioEngine.play()
        setupNowPlaying()
    }
    
    func togglePlayPause() {
        audioEngine.togglePlayPause()
        updateNowPlaying()
    }
    
    func seekBegan() {
        isSeeking = true
        seekTime = audioEngine.currentTime
    }
    
    func seekChanged(to time: TimeInterval) {
        seekTime = time
    }
    
    func seekEnded() {
        audioEngine.seek(to: seekTime)
        isSeeking = false
    }
    
    // MARK: - Presets
    
    func selectPreset(_ preset: AudioPreset) {
        selectedPreset = preset
        audioEngine.applyPreset(preset)
    }
    
    // MARK: - Now Playing Info (ロック画面表示)
    
    private func setupNowPlaying() {
        guard let track = currentTrack else { return }
        
        var info = [String: Any]()
        info[MPMediaItemPropertyTitle] = track.title
        info[MPMediaItemPropertyArtist] = track.artist
        info[MPMediaItemPropertyPlaybackDuration] = duration
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = audioEngine.currentTime
        info[MPNowPlayingInfoPropertyPlaybackRate] = audioEngine.isPlaying ? audioEngine.rate : 0
        
        if let artwork = track.artwork,
           let image = artwork.image(at: CGSize(width: 600, height: 600)) {
            info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
        }
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
    
    private func updateNowPlaying() {
        guard MPNowPlayingInfoCenter.default().nowPlayingInfo != nil else { return }
        MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPNowPlayingInfoPropertyElapsedPlaybackTime] = audioEngine.currentTime
        MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPNowPlayingInfoPropertyPlaybackRate] = audioEngine.isPlaying ? audioEngine.rate : 0
    }
    
    // MARK: - Remote Commands (ロック画面コントロール)
    
    func setupRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        
        center.playCommand.addTarget { [weak self] _ in
            self?.audioEngine.play()
            return .success
        }
        
        center.pauseCommand.addTarget { [weak self] _ in
            self?.audioEngine.pause()
            return .success
        }
        
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.audioEngine.togglePlayPause()
            return .success
        }
        
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            self?.audioEngine.seek(to: event.positionTime)
            return .success
        }
    }
    
    // MARK: - Helpers
    
    private func formatTime(_ time: TimeInterval) -> String {
        let mins = Int(time) / 60
        let secs = Int(time) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

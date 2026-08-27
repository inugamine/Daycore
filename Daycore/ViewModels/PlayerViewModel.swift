//
//  PlayerViewModel.swift
//  Daycore
//
//  Created by inugaminé on 2026/05/25.
//

import Foundation
import Combine
import MediaPlayer
import UIKit
import AVFoundation

/// プレーヤー画面の ViewModel
/// AudioEngineService と MusicLibraryService を橋渡しする
@MainActor
final class PlayerViewModel: ObservableObject {
    
    // MARK: - Services
    
    let audioEngine = AudioEngineService()
    var musicLibrary = MusicLibraryService()
    private let nowPlaying = NowPlayingService()
    
    // MARK: - Published State
    
    @Published var currentTrack: Track?
    @Published var selectedPreset: AudioPreset = .daycore
    @Published var showingLibrary = false
    @Published var showingFileImporter = false
    @Published var isSeeking = false
    @Published var repeatMode: RepeatMode = .off
    @Published var isShuffled = false
    
    enum RepeatMode: CaseIterable {
        case off, all, one
        
        var icon: String {
            switch self {
            case .off:  return "repeat"
            case .all:  return "repeat"
            case .one:  return "repeat.1"
            }
        }
        
        var isActive: Bool { self != .off }
        
        func next() -> RepeatMode {
            switch self {
            case .off:  return .one
            case .one:  return .all
            case .all:  return .off
            }
        }
    }
    
    // スライダー用（シーク中はユーザーの操作値を保持）
    @Published var seekTime: TimeInterval = 0
    
    private var cancellables = Set<AnyCancellable>()

    /// Now Playing への連続書き込みをまとめるためのタスク
    private var nowPlayingCoalesceTask: Task<Void, Never>?
    
    /// 現在のトラックのアートワーク画像（Now Playing・再生画面 共用キャッシュ）
    @Published private(set) var currentArtworkImage: UIImage?
    
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
        
        // トラック終了時のハンドラ
        audioEngine.onTrackFinished = { [weak self] in
            self?.handleTrackFinished()
        }
    }
    
    // MARK: - Repeat & Shuffle
    
    func toggleRepeatMode() {
        repeatMode = repeatMode.next()
    }
    
    func toggleShuffle() {
        isShuffled.toggle()
    }
    
    private func handleTrackFinished() {
        switch repeatMode {
        case .one:
            // 1曲リピート: エンジンを止めずに先頭から再スケジュール
            audioEngine.replay()
            postNowPlayingUpdate()
        case .all:
            playNextTrack()
        case .off:
            // 再生は終わっている。ロック画面にも停止を反映する。
            postNowPlayingUpdate()
        }
    }
    
    private func playNextTrack() {
        let allTracks = musicLibrary.filteredTracks
        guard !allTracks.isEmpty, let current = currentTrack else {
            // 曲がない場合は同じ曲をリプレイ
            audioEngine.seek(to: 0)
            audioEngine.play()
            return
        }
        
        if isShuffled {
            // シャッフル: ランダムに次の曲を選ぶ
            let candidates = allTracks.filter { $0.id != current.id }
            if let next = candidates.randomElement() {
                selectTrack(next)
            } else {
                selectTrack(current)
            }
        } else {
            // 順序再生: 次の曲へ
            if let idx = allTracks.firstIndex(where: { $0.id == current.id }) {
                let nextIdx = (idx + 1) % allTracks.count
                selectTrack(allTracks[nextIdx])
            } else {
                audioEngine.seek(to: 0)
                audioEngine.play()
            }
        }
    }
    
    /// 前の曲へ。ただし3秒以上再生している場合は「頭出し」にする。
    /// ロック画面からも呼ばれるので位置判定に livePosition を使う。
    private func playPreviousTrack() {
        if audioEngine.livePosition > 3 {
            audioEngine.seek(to: 0)
            postNowPlayingUpdate()
            return
        }

        let allTracks = musicLibrary.filteredTracks
        guard !allTracks.isEmpty,
              let current = currentTrack,
              let idx = allTracks.firstIndex(where: { $0.id == current.id }) else {
            audioEngine.seek(to: 0)
            postNowPlayingUpdate()
            return
        }

        let prevIdx = (idx - 1 + allTracks.count) % allTracks.count
        selectTrack(allTracks[prevIdx])
    }

    // MARK: - Playback
    
    func selectTrack(_ track: Track) {
        currentTrack = track
        loadArtworkForCurrentTrack(track)
        audioEngine.loadTrack(track)
        audioEngine.applyPreset(selectedPreset)
        audioEngine.play()
        postNowPlayingUpdate()
    }
    
    func togglePlayPause() {
        audioEngine.togglePlayPause()
        postNowPlayingUpdate()
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
        postNowPlayingUpdate()
    }

    /// 現在位置から相対でシークする（±15秒ボタン / ロック画面用）
    func skip(by seconds: TimeInterval) {
        let target = min(max(0, audioEngine.livePosition + seconds), duration)
        audioEngine.seek(to: target)
        postNowPlayingUpdate()
    }
    
    // MARK: - Presets
    
    func selectPreset(_ preset: AudioPreset) {
        selectedPreset = preset
        audioEngine.applyPreset(preset)
        // rate が変わったら必ず再送する。
        // ロック画面は playbackRate を使って自前で時間を進めるため、
        // 送らないと進捗バーだけが違う速度で走り続ける。
        postNowPlayingUpdate()
    }

    /// 再生速度を直接変更する（Speed スライダー用）。
    /// View から audioEngine.rate を直叩きすると Now Playing を素通りするので、
    /// 必ずここを通すこと。
    func setRate(_ newRate: Float) {
        audioEngine.rate = newRate
        postNowPlayingUpdateCoalesced()
    }

    /// ピッチを直接変更する（Pitch スライダー用）
    func setPitch(_ newPitch: Float) {
        audioEngine.pitch = newPitch
        postNowPlayingUpdateCoalesced()
    }
    
    // MARK: - Now Playing Info（ロック画面表示）
    
    /// 現在の状態をロック画面 / コントロールセンターへ送る。
    ///
    /// **状態が変わる経路からは必ずこれを呼ぶこと。**
    /// 送り忘れはそのまま「ロック画面だけ現実とズレている」状態になる。
    private func postNowPlayingUpdate() {
        nowPlayingCoalesceTask?.cancel()
        nowPlayingCoalesceTask = nil

        guard let track = currentTrack else {
            nowPlaying.clear()
            return
        }

        nowPlaying.update(
            NowPlayingService.Snapshot(
                trackID: track.id,
                title: track.title,
                artist: track.artist,
                albumTitle: track.albumTitle,
                duration: duration,
                // currentTime ではなく livePosition を使うこと。
                // ロック中は CADisplayLink が止まって currentTime が凍るため、
                // そのまま送るとロック画面の時計が過去に飛ぶ。
                elapsed: audioEngine.livePosition,
                rate: audioEngine.isPlaying ? audioEngine.rate : 0,
                artworkImage: currentArtworkImage
            )
        )
    }

    /// スライダーのドラッグのような連続操作では、
    /// 毎フレーム IPC を叩かずに短時間まとめて 1 回だけ送る。
    private func postNowPlayingUpdateCoalesced() {
        nowPlayingCoalesceTask?.cancel()
        nowPlayingCoalesceTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }
            self?.postNowPlayingUpdate()
        }
    }
    
    /// 現在のトラックのアートワーク画像を読み込んでキャッシュする
    private func loadArtworkForCurrentTrack(_ track: Track) {
        switch track.source {
        case .library:
            // MPMediaItemArtwork.image(at:) はメインスレッドで呼ぶこと。
            //
            // 注意: この制約の根拠は未確認。過去の実機クラッシュを踏んで
            // 書かれた可能性があるため、推測でバックグラウンドに逃がすのはやめている。
            // 代償は曲選択時にメインスレッドで 1 枚デコードが走ること。
            // 変更するなら先に実機でクラッシュしないことを確かめろ。
            currentArtworkImage = track.artwork?.image(at: CGSize(width: 600, height: 600))
        case .file(let url):
            currentArtworkImage = nil
            let trackID = track.id
            // ファイル埋め込み画像の読み出しは重いのでバックグラウンドで実行
            Task.detached(priority: .utility) { [weak self] in
                let image = PlayerViewModel.loadArtwork(from: url)
                await self?.applyLoadedArtwork(image, forTrackID: trackID)
            }
        }
    }
    
    /// バックグラウンド読み込み完了後にアートワークを反映する
    private func applyLoadedArtwork(_ image: UIImage?, forTrackID id: String) {
        guard currentTrack?.id == id, let image else { return }
        currentArtworkImage = image
        postNowPlayingUpdate()
    }
    
    /// ファイルに埋め込まれたアートワーク画像を読み出す（MP3/M4A 等）
    nonisolated static func loadArtwork(from url: URL) -> UIImage? {
        let accessed = url.startAccessingSecurityScopedResource()
        defer {
            if accessed { url.stopAccessingSecurityScopedResource() }
        }
        
        let asset = AVURLAsset(url: url)
        for item in asset.commonMetadata where item.commonKey == .commonKeyArtwork {
            if let data = item.dataValue, let image = UIImage(data: data) {
                return image
            }
        }
        return nil
    }
    
    // MARK: - Remote Commands (ロック画面コントロール)
    
    func setupRemoteCommands() {
        nowPlaying.registerCommands(
            NowPlayingService.CommandHandlers(
                play: { [weak self] in
                    guard let self else { return }
                    self.audioEngine.play()
                    self.postNowPlayingUpdate()
                },
                pause: { [weak self] in
                    guard let self else { return }
                    self.audioEngine.pause()
                    self.postNowPlayingUpdate()
                },
                togglePlayPause: { [weak self] in
                    self?.togglePlayPause()
                },
                nextTrack: { [weak self] in
                    self?.playNextTrack()
                },
                previousTrack: { [weak self] in
                    self?.playPreviousTrack()
                },
                seek: { [weak self] time in
                    guard let self else { return }
                    self.audioEngine.seek(to: time)
                    self.postNowPlayingUpdate()
                }
            )
        )
    }
    
    // MARK: - Helpers
    
    private func formatTime(_ time: TimeInterval) -> String {
        let mins = Int(time) / 60
        let secs = Int(time) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

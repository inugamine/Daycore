//
//  AudioEngineService.swift
//  Daycore
//
//  Created by inugaminé on 2026/05/25.
//

import Foundation
import AVFoundation
import Combine
import MediaPlayer

/// AVAudioEngine を使ったリアルタイム音声処理サービス
/// ピッチ変更・再生速度変更を担う Daycore アプリの心臓部
final class AudioEngineService: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var rate: Float = 0.80 {
        didSet { timePitchNode.rate = rate }
    }
    @Published var pitch: Float = -3.0 {
        didSet { timePitchNode.pitch = pitch * 100 } // semitones → cents
    }
    
    // MARK: - Audio Nodes (nonisolated(unsafe) — deinit からのアクセスに必要)
    
    nonisolated(unsafe) private let engine = AVAudioEngine()
    nonisolated(unsafe) private let playerNode = AVAudioPlayerNode()
    nonisolated(unsafe) private let timePitchNode = AVAudioUnitTimePitch()
    
    // MARK: - State
    
    private var audioFile: AVAudioFile?
    private var seekFrame: AVAudioFramePosition = 0
    private var currentFileFrameLength: AVAudioFramePosition = 0
    nonisolated(unsafe) private var displayLink: CADisplayLink?
    private var cancellables = Set<AnyCancellable>()
    private var playbackGeneration: Int = 0
    
    /// トラック再生完了時のコールバック
    var onTrackFinished: (() -> Void)?
    
    // MARK: - Init
    
    init() {
        setupEngine()
        setupAudioSession()
    }
    
    deinit {
        displayLink?.invalidate()
        engine.stop()
    }
    
    // MARK: - Setup
    
    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.allowBluetoothA2DP])
            try session.setActive(true)
        } catch {
            print("[AudioEngine] セッション設定失敗: \(error)")
        }
        
        // オーディオルート変更監視（Bluetooth 接続/切断時）
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let info = notification.userInfo,
                  let reasonValue = info[AVAudioSessionRouteChangeReasonKey] as? UInt,
                  let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else { return }
            self?.handleRouteChange(reason: reason)
        }
        
        // オーディオセッション中断ハンドリング
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let info = notification.userInfo,
                  let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }
            let shouldResume: Bool
            if type == .ended {
                let options = info[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
                shouldResume = AVAudioSession.InterruptionOptions(rawValue: options).contains(.shouldResume)
            } else {
                shouldResume = false
            }
            self?.handleInterruption(type: type, shouldResume: shouldResume)
        }
    }
    
    // MARK: - Route Change
    
    private func handleRouteChange(reason: AVAudioSession.RouteChangeReason) {
        switch reason {
        case .newDeviceAvailable:
            // Bluetooth 接続等: エンジンが止まっていたら再構築
            rebuildEngineIfNeeded()
        case .oldDeviceUnavailable:
            // Bluetooth 切断等: エンジンを停止してノードを再接続
            let savedTime = currentTime
            let savedSeekFrame = seekFrame
            
            playbackGeneration += 1 // 古い完了コールバックを無効化
            playerNode.stop()
            engine.stop()
            isPlaying = false
            stopDisplayLink()
            
            // ノードを新しいフォーマットで再接続
            engine.disconnectNodeOutput(playerNode)
            engine.disconnectNodeOutput(timePitchNode)
            engine.connect(playerNode, to: timePitchNode, format: nil)
            engine.connect(timePitchNode, to: engine.mainMixerNode, format: nil)
            
            // 再生位置を保持（再生ボタンで続きから再開）
            seekFrame = savedSeekFrame
            currentTime = savedTime
        default:
            rebuildEngineIfNeeded()
        }
    }
    
    private func rebuildEngineIfNeeded() {
        guard !engine.isRunning else { return }
        
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setActive(true)
        } catch {
            print("[AudioEngine] セッション再アクティベート失敗: \(error)")
        }
        
        engine.disconnectNodeOutput(playerNode)
        engine.disconnectNodeOutput(timePitchNode)
        engine.connect(playerNode, to: timePitchNode, format: nil)
        engine.connect(timePitchNode, to: engine.mainMixerNode, format: nil)
        
        do {
            try engine.start()
        } catch {
            print("[AudioEngine] エンジン再起動失敗: \(error)")
        }
    }
    
    private func handleInterruption(type: AVAudioSession.InterruptionType, shouldResume: Bool) {
        switch type {
        case .began:
            pause()
        case .ended:
            if shouldResume { play() }
        @unknown default:
            break
        }
    }
    
    private func setupEngine() {
        engine.attach(playerNode)
        engine.attach(timePitchNode)
        
        // playerNode → timePitch → mainMixer → output
        engine.connect(playerNode, to: timePitchNode, format: nil)
        engine.connect(timePitchNode, to: engine.mainMixerNode, format: nil)
        
        // 初期値の適用
        timePitchNode.rate = rate
        timePitchNode.pitch = pitch * 100
    }
    
    // MARK: - Load Track
    
    /// トラックを読み込む
    func loadTrack(_ track: Track) {
        playbackGeneration += 1
        stop()
        
        do {
            switch track.source {
            case .library(let mediaItem):
                guard let assetURL = mediaItem.assetURL else {
                    print("[AudioEngine] DRM保護された曲または URL 取得不可")
                    return
                }
                audioFile = try AVAudioFile(forReading: assetURL)
                
            case .file(let url):
                // セキュリティスコープ付きアクセス
                let accessed = url.startAccessingSecurityScopedResource()
                defer {
                    if accessed { url.stopAccessingSecurityScopedResource() }
                }
                audioFile = try AVAudioFile(forReading: url)
            }
            
            guard let file = audioFile else { return }
            
            currentFileFrameLength = file.length
            let sampleRate = file.processingFormat.sampleRate
            duration = Double(currentFileFrameLength) / sampleRate
            currentTime = 0
            seekFrame = 0
            
        } catch {
            print("[AudioEngine] ファイル読み込み失敗: \(error)")
        }
    }
    
    // MARK: - Playback Controls
    
    func play() {
        guard let file = audioFile else { return }
        
        if !engine.isRunning {
            do {
                try engine.start()
            } catch {
                print("[AudioEngine] エンジン起動失敗: \(error)")
                return
            }
        }
        
        // 現在位置を seekFrame から再計算（曲切り替え時の残留値防止）
        if let sampleRate = audioFile?.processingFormat.sampleRate, sampleRate > 0 {
            currentTime = Double(seekFrame) / sampleRate
        }
        
        // 残りのフレーム数を計算してスケジュール
        let gen = playbackGeneration
        let remainingFrames = AVAudioFrameCount(currentFileFrameLength - seekFrame)
        guard remainingFrames > 0 else {
            // 最後まで再生済み → 先頭に戻す
            seekFrame = 0
            let allFrames = AVAudioFrameCount(currentFileFrameLength)
            playerNode.scheduleSegment(
                file,
                startingFrame: 0,
                frameCount: allFrames,
                at: nil,
                completionCallbackType: .dataPlayedBack
            ) { [weak self] _ in
                self?.handlePlaybackComplete(generation: gen)
            }
            playerNode.play()
            isPlaying = true
            startDisplayLink()
            return
        }
        
        playerNode.scheduleSegment(
            file,
            startingFrame: seekFrame,
            frameCount: remainingFrames,
            at: nil,
            completionCallbackType: .dataPlayedBack
        ) { [weak self] _ in
            self?.handlePlaybackComplete(generation: gen)
        }
        playerNode.play()
        isPlaying = true
        startDisplayLink()
    }
    
    func pause() {
        playerNode.pause()
        isPlaying = false
        stopDisplayLink()
        
        // 現在位置を保存
        if let nodeTime = playerNode.lastRenderTime,
           let playerTime = playerNode.playerTime(forNodeTime: nodeTime) {
            seekFrame = playerTime.sampleTime + seekFrame
        }
    }
    
    func stop() {
        playerNode.stop()
        isPlaying = false
        stopDisplayLink()
        seekFrame = 0
        currentTime = 0
    }
    
    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }
    
    /// エンジンを止めずに先頭から再スケジュール（リピート用、無音なし）
    func replay() {
        guard let file = audioFile else { return }
        
        playerNode.stop()
        seekFrame = 0
        currentTime = 0
        
        let allFrames = AVAudioFrameCount(currentFileFrameLength)
        let gen = playbackGeneration
        playerNode.scheduleSegment(
            file,
            startingFrame: 0,
            frameCount: allFrames,
            at: nil,
            completionCallbackType: .dataPlayedBack
        ) { [weak self] _ in
            self?.handlePlaybackComplete(generation: gen)
        }
        playerNode.play()
        isPlaying = true
        startDisplayLink()
    }
    
    /// 指定した時間（秒）にシークする
    func seek(to time: TimeInterval) {
        guard let file = audioFile else { return }
        
        playbackGeneration += 1
        let gen = playbackGeneration
        
        let sampleRate = file.processingFormat.sampleRate
        let targetFrame = AVAudioFramePosition(time * sampleRate)
        seekFrame = max(0, min(targetFrame, currentFileFrameLength))
        currentTime = time
        
        let wasPlaying = isPlaying
        playerNode.stop()
        
        if wasPlaying {
            let remainingFrames = AVAudioFrameCount(currentFileFrameLength - seekFrame)
            guard remainingFrames > 0 else { return }
            
            playerNode.scheduleSegment(
                file,
                startingFrame: seekFrame,
                frameCount: remainingFrames,
                at: nil,
                completionCallbackType: .dataPlayedBack
            ) { [weak self] _ in
                self?.handlePlaybackComplete(generation: gen)
            }
            playerNode.play()
        }
    }
    
    /// プリセットを適用
    func applyPreset(_ preset: AudioPreset) {
        rate = preset.rate
        pitch = preset.pitch
    }
    
    // MARK: - Display Link (時間更新)
    
    private func startDisplayLink() {
        displayLink = CADisplayLink(target: self, selector: #selector(updatePlaybackTime))
        displayLink?.preferredFrameRateRange = CAFrameRateRange(minimum: 15, maximum: 30)
        displayLink?.add(to: .main, forMode: .common)
    }
    
    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }
    
    @objc private func updatePlaybackTime() {
        guard isPlaying,
              let nodeTime = playerNode.lastRenderTime,
              let playerTime = playerNode.playerTime(forNodeTime: nodeTime),
              let file = audioFile else { return }
        
        let sampleRate = file.processingFormat.sampleRate
        let elapsedFrames = playerTime.sampleTime + seekFrame
        currentTime = Double(elapsedFrames) / sampleRate
        
        // 再生完了チェック（画面点灯時のフォールバック、主な検知は完了コールバックで行う）
        if elapsedFrames >= currentFileFrameLength {
            currentTime = duration
        }
    }
    
    /// オーディオスレッドからの再生完了通知（画面オフでも動作）
    private func handlePlaybackComplete(generation: Int) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, generation == self.playbackGeneration else { return }
            self.stop()
            self.onTrackFinished?()
        }
    }
}

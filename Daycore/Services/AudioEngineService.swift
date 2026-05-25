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
    
    // MARK: - Audio Nodes
    
    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let timePitchNode = AVAudioUnitTimePitch()
    
    // MARK: - State
    
    private var audioFile: AVAudioFile?
    private var seekFrame: AVAudioFramePosition = 0
    private var currentFileFrameLength: AVAudioFramePosition = 0
    private var displayLink: CADisplayLink?
    private var cancellables = Set<AnyCancellable>()
    
    /// トラック再生完了時のコールバック
    var onTrackFinished: (() -> Void)?
    
    // MARK: - Init
    
    init() {
        setupEngine()
        setupAudioSession()
    }
    
    deinit {
        stopDisplayLink()
        engine.stop()
    }
    
    // MARK: - Setup
    
    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
        } catch {
            print("[AudioEngine] セッション設定失敗: \(error)")
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
        
        // 残りのフレーム数を計算してスケジュール
        let remainingFrames = AVAudioFrameCount(currentFileFrameLength - seekFrame)
        guard remainingFrames > 0 else {
            // 最後まで再生済み → 先頭に戻す
            seekFrame = 0
            let allFrames = AVAudioFrameCount(currentFileFrameLength)
            playerNode.scheduleSegment(
                file,
                startingFrame: 0,
                frameCount: allFrames,
                at: nil
            )
            playerNode.play()
            isPlaying = true
            startDisplayLink()
            return
        }
        
        playerNode.scheduleSegment(
            file,
            startingFrame: seekFrame,
            frameCount: remainingFrames,
            at: nil
        )
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
    
    /// 指定した時間（秒）にシークする
    func seek(to time: TimeInterval) {
        guard let file = audioFile else { return }
        
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
                at: nil
            )
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
        
        // 再生完了チェック
        if elapsedFrames >= currentFileFrameLength {
            stop()
            onTrackFinished?()
        }
    }
}

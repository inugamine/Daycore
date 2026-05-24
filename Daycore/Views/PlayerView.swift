//
//  PlayerView.swift
//  Daycore
//
//  Created by inugaminé on 2026/05/25.
//

import SwiftUI
import MediaPlayer

/// メインプレーヤー画面
struct PlayerView: View {
    @ObservedObject var viewModel: PlayerViewModel
    
    var body: some View {
        ZStack {
            // 背景
            DaycoreTheme.backgroundGradient
                .ignoresSafeArea()
            
            if let track = viewModel.currentTrack {
                playerContent(track)
            } else {
                emptyState
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "moon.stars")
                .font(.system(size: 80))
                .foregroundStyle(DaycoreTheme.accentGradient)
            
            Text("Daycore")
                .font(.largeTitle.bold())
                .foregroundColor(DaycoreTheme.textPrimary)
            
            Text("曲を選んで Daycore の世界へ")
                .font(.subheadline)
                .foregroundColor(DaycoreTheme.textSecondary)
            
            Button {
                viewModel.showingLibrary = true
            } label: {
                Label("ライブラリを開く", systemImage: "music.note.list")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background(DaycoreTheme.accentGradient)
                    .clipShape(Capsule())
            }
            .padding(.top, 12)
        }
    }
    
    // MARK: - Player Content
    
    private func playerContent(_ track: Track) -> some View {
        VStack(spacing: 0) {
            Spacer()
            
            // アートワーク
            artworkView(track)
                .padding(.bottom, 32)
            
            // トラック情報
            trackInfo(track)
                .padding(.bottom, 24)
            
            // シークバー
            seekBar
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            
            // 再生コントロール
            playbackControls
                .padding(.bottom, 28)
            
            // プリセットセレクタ
            presetSelector
                .padding(.bottom, 16)
            
            // Rate / Pitch スライダー
            parameterSliders
                .padding(.horizontal, 24)
            
            Spacer()
        }
    }
    
    // MARK: - Artwork
    
    private func artworkView(_ track: Track) -> some View {
        Group {
            if let artwork = track.artwork,
               let image = artwork.image(at: CGSize(width: 300, height: 300)) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    DaycoreTheme.surface
                    Image(systemName: "music.note")
                        .font(.system(size: 60))
                        .foregroundColor(DaycoreTheme.accent)
                }
            }
        }
        .frame(width: 280, height: 280)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: DaycoreTheme.accentGlow, radius: 30, y: 10)
    }
    
    // MARK: - Track Info
    
    private func trackInfo(_ track: Track) -> some View {
        VStack(spacing: 6) {
            Text(track.title)
                .font(.title3.bold())
                .foregroundColor(DaycoreTheme.textPrimary)
                .lineLimit(1)
            
            Text(track.artist)
                .font(.subheadline)
                .foregroundColor(DaycoreTheme.textSecondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 24)
    }
    
    // MARK: - Seek Bar
    
    private var seekBar: some View {
        VStack(spacing: 4) {
            Slider(
                value: Binding(
                    get: { viewModel.displayTime },
                    set: { viewModel.seekChanged(to: $0) }
                ),
                in: 0...max(viewModel.duration, 0.01),
                onEditingChanged: { editing in
                    if editing {
                        viewModel.seekBegan()
                    } else {
                        viewModel.seekEnded()
                    }
                }
            )
            .tint(DaycoreTheme.accent)
            
            HStack {
                Text(viewModel.currentTimeFormatted)
                Spacer()
                Text(viewModel.durationFormatted)
            }
            .font(.caption)
            .foregroundColor(DaycoreTheme.textMuted)
        }
    }
    
    // MARK: - Playback Controls
    
    private var playbackControls: some View {
        HStack(spacing: 48) {
            // 15秒戻る
            Button {
                let newTime = max(0, viewModel.audioEngine.currentTime - 15)
                viewModel.audioEngine.seek(to: newTime)
            } label: {
                Image(systemName: "gobackward.15")
                    .font(.title2)
                    .foregroundColor(DaycoreTheme.textPrimary)
            }
            
            // 再生/一時停止
            Button {
                viewModel.togglePlayPause()
            } label: {
                Image(systemName: viewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(DaycoreTheme.accentGradient)
                    .shadow(color: DaycoreTheme.accentGlow, radius: 12)
            }
            
            // 15秒進む
            Button {
                let newTime = min(viewModel.duration, viewModel.audioEngine.currentTime + 15)
                viewModel.audioEngine.seek(to: newTime)
            } label: {
                Image(systemName: "goforward.15")
                    .font(.title2)
                    .foregroundColor(DaycoreTheme.textPrimary)
            }
        }
    }
    
    // MARK: - Preset Selector
    
    private var presetSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(AudioPreset.allPresets) { preset in
                    presetButton(preset)
                }
            }
            .padding(.horizontal, 24)
        }
    }
    
    private func presetButton(_ preset: AudioPreset) -> some View {
        let isSelected = viewModel.selectedPreset == preset
        
        return Button {
            viewModel.selectPreset(preset)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: preset.icon)
                    .font(.caption)
                Text(preset.name)
                    .font(.caption.bold())
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                isSelected
                ? AnyShapeStyle(DaycoreTheme.accentGradient)
                : AnyShapeStyle(DaycoreTheme.surface)
            )
            .foregroundColor(isSelected ? .white : DaycoreTheme.textSecondary)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.clear : DaycoreTheme.divider, lineWidth: 1)
            )
        }
    }
    
    // MARK: - Parameter Sliders
    
    private var parameterSliders: some View {
        VStack(spacing: 16) {
            // Rate (速度)
            DaycoreSlider(
                label: "Speed",
                value: Binding(
                    get: { viewModel.audioEngine.rate },
                    set: { viewModel.audioEngine.rate = $0 }
                ),
                range: 0.25...2.0,
                icon: "speedometer",
                displayFormat: "%.2fx"
            )
            
            // Pitch
            DaycoreSlider(
                label: "Pitch",
                value: Binding(
                    get: { viewModel.audioEngine.pitch },
                    set: { viewModel.audioEngine.pitch = $0 }
                ),
                range: -12...12,
                icon: "tuningfork",
                displayFormat: "%+.1f st"
            )
        }
    }
}

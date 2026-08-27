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
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    private var isCompact: Bool { horizontalSizeClass == .compact }
    
    var body: some View {
        ZStack {
            DaycoreTheme.backgroundGradient
                .ignoresSafeArea()
            
            if let track = viewModel.currentTrack {
                // iPadOS 27: ウィンドウは任意サイズにリサイズされる。
                // 高さが足りる時は従来通り全体表示（バウンスもしない）、
                // 足りない時だけスクロールにフォールバックして、
                // コントロールが画面外に切れて操作不能になるのを防ぐ。
                GeometryReader { geo in
                    let layout = PlayerLayout(height: geo.size.height, width: geo.size.width)
                    ScrollView {
                        playerContent(track, layout: layout)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: geo.size.height)
                    }
                    .scrollBounceBehavior(.basedOnSize)
                }
            } else {
                emptyState
            }
        }
    }
    
    // MARK: - Layout 計算
    
    /// 画面サイズに応じたレイアウト値
    private struct PlayerLayout {
        let artworkSize: CGFloat
        let artworkCorner: CGFloat
        let playButtonSize: CGFloat
        let spacing: CGFloat
        let horizontalPadding: CGFloat
        let sliderSpacing: CGFloat
        
        init(height: CGFloat, width: CGFloat) {
            let h = height
            // アートワーク: 高さの30%、ただし最小100 最大300
            artworkSize = min(max(h * 0.30, 100), 300)
            artworkCorner = artworkSize * 0.07
            // 再生ボタン: 高さに応じてスケール
            playButtonSize = min(max(h * 0.075, 44), 64)
            // 要素間のスペーシング
            spacing = max(h * 0.015, 4)
            horizontalPadding = min(width * 0.06, 24)
            sliderSpacing = max(h * 0.01, 4)
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "waveform")
                .font(.system(size: 80))
                .foregroundStyle(DaycoreTheme.accentGradient)
            
            Text("Daycore")
                .font(.largeTitle.bold())
                .foregroundColor(DaycoreTheme.textPrimary)
            
            Text("曲を選んで Daycore の世界へ")
                .font(.subheadline)
                .foregroundColor(DaycoreTheme.textSecondary)
            
            if isCompact {
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
    }
    
    // MARK: - Player Content
    
    private func playerContent(_ track: Track, layout: PlayerLayout) -> some View {
        VStack(spacing: layout.spacing) {
            Spacer(minLength: 0)
            
            // アートワーク
            artworkView(track, size: layout.artworkSize, corner: layout.artworkCorner)
            
            // トラック情報
            trackInfo(track)
                .padding(.top, layout.spacing)
            
            // シークバー
            seekBar
                .padding(.horizontal, layout.horizontalPadding)
                .padding(.top, layout.spacing)
            
            // 再生コントロール
            playbackControls(buttonSize: layout.playButtonSize)
                .padding(.top, layout.spacing)
            
            // プリセットセレクタ
            presetSelector
                .padding(.top, layout.spacing)
            
            // Rate / Pitch スライダー
            parameterSliders(spacing: layout.sliderSpacing)
                .padding(.horizontal, layout.horizontalPadding)
                .padding(.top, layout.spacing)
            
            Spacer(minLength: 0)
        }
    }
    
    // MARK: - Artwork
    
    private func artworkView(_ track: Track, size: CGFloat, corner: CGFloat) -> some View {
        Group {
            // ViewModel のキャッシュを使う（ライブラリ曲・ファイル曲両対応、
            // 再描画のたびに image(at:) を呼び直さない）
            if let image = viewModel.currentArtworkImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    DaycoreTheme.surface
                    Image(systemName: "music.note")
                        .font(.system(size: size * 0.2))
                        .foregroundColor(DaycoreTheme.accent)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: corner))
        .shadow(color: DaycoreTheme.accentGlow, radius: 20, y: 8)
    }
    
    // MARK: - Track Info
    
    private func trackInfo(_ track: Track) -> some View {
        VStack(spacing: 4) {
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
        VStack(spacing: 2) {
            Slider(
                value: Binding(
                    get: { viewModel.displayTime },
                    set: { viewModel.seekChanged(to: $0) }
                ),
                in: 0...max(viewModel.duration, 0.01),
                onEditingChanged: { editing in
                    if editing { viewModel.seekBegan() }
                    else { viewModel.seekEnded() }
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
    
    private func playbackControls(buttonSize: CGFloat) -> some View {
        HStack(spacing: buttonSize * 0.45) {
            Button { viewModel.toggleShuffle() } label: {
                Image(systemName: "shuffle")
                    .font(.system(size: buttonSize * 0.3))
                    .foregroundColor(viewModel.isShuffled ? DaycoreTheme.accent : DaycoreTheme.textMuted)
            }
            
            Button {
                viewModel.skip(by: -15)
            } label: {
                Image(systemName: "gobackward.15")
                    .font(.system(size: buttonSize * 0.45))
                    .foregroundColor(DaycoreTheme.textPrimary)
            }
            
            Button { viewModel.togglePlayPause() } label: {
                Image(systemName: viewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: buttonSize))
                    .foregroundStyle(DaycoreTheme.accentGradient)
                    .shadow(color: DaycoreTheme.accentGlow, radius: 10)
            }
            
            Button {
                viewModel.skip(by: 15)
            } label: {
                Image(systemName: "goforward.15")
                    .font(.system(size: buttonSize * 0.45))
                    .foregroundColor(DaycoreTheme.textPrimary)
            }
            
            Button { viewModel.toggleRepeatMode() } label: {
                Image(systemName: viewModel.repeatMode.icon)
                    .font(.system(size: buttonSize * 0.3))
                    .foregroundColor(viewModel.repeatMode.isActive ? DaycoreTheme.accent : DaycoreTheme.textMuted)
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
    
    private func parameterSliders(spacing: CGFloat) -> some View {
        VStack(spacing: spacing) {
            // audioEngine を直叩きしないこと。
            // ViewModel を経由しないと Now Playing への再送が抜け、
            // ロック画面の進捗バーだけが古い rate のまま走り続ける。
            DaycoreSlider(
                label: "Speed",
                value: Binding(
                    get: { viewModel.audioEngine.rate },
                    set: { viewModel.setRate($0) }
                ),
                range: 0.25...2.0,
                icon: "speedometer",
                displayFormat: "%.2fx"
            )
            
            DaycoreSlider(
                label: "Pitch",
                value: Binding(
                    get: { viewModel.audioEngine.pitch },
                    set: { viewModel.setPitch($0) }
                ),
                range: -12...12,
                icon: "tuningfork",
                displayFormat: "%+.1f st"
            )
        }
    }
}

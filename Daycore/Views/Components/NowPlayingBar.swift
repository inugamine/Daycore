//
//  NowPlayingBar.swift
//  Daycore
//
//  Created by inugaminé on 2026/05/25.
//

import SwiftUI
import MediaPlayer

/// 画面下部に表示するミニプレーヤーバー
struct NowPlayingBar: View {
    @ObservedObject var viewModel: PlayerViewModel
    let onTap: () -> Void
    
    var body: some View {
        if let track = viewModel.currentTrack {
            VStack(spacing: 0) {
                // プログレスバー
                GeometryReader { geo in
                    Rectangle()
                        .fill(DaycoreTheme.accent)
                        .frame(width: geo.size.width * viewModel.progress)
                }
                .frame(height: 2)
                
                HStack(spacing: 12) {
                    // アートワーク
                    miniArtwork(track)
                    
                    // トラック情報
                    VStack(alignment: .leading, spacing: 2) {
                        Text(track.title)
                            .font(.subheadline.bold())
                            .foregroundColor(DaycoreTheme.textPrimary)
                            .lineLimit(1)
                        
                        Text(viewModel.selectedPreset.name)
                            .font(.caption)
                            .foregroundColor(DaycoreTheme.accent)
                    }
                    
                    Spacer()
                    
                    // 再生/一時停止
                    Button {
                        viewModel.togglePlayPause()
                    } label: {
                        Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                            .font(.title3)
                            .foregroundColor(DaycoreTheme.textPrimary)
                    }
                    .padding(.trailing, 4)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            .background(
                DaycoreTheme.surface
                    .overlay(DaycoreTheme.accentGlow.opacity(0.05))
            )
            .contentShape(Rectangle())
            .onTapGesture(perform: onTap)
        }
    }
    
    private func miniArtwork(_ track: Track) -> some View {
        Group {
            if let artwork = track.artwork,
               let image = artwork.image(at: CGSize(width: 44, height: 44)) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    DaycoreTheme.surfaceLight
                    Image(systemName: "music.note")
                        .font(.caption)
                        .foregroundColor(DaycoreTheme.accent)
                }
            }
        }
        .frame(width: 40, height: 40)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

//
//  TrackRow.swift
//  Daycore
//
//  Created by inugaminé on 2026/05/25.
//

import SwiftUI
import MediaPlayer

/// トラックリストの1行表示
struct TrackRow: View {
    let track: Track
    let isPlaying: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // アートワークサムネイル
            artworkThumbnail
            
            // タイトル・アーティスト
            VStack(alignment: .leading, spacing: 3) {
                Text(track.title)
                    .font(.subheadline.bold())
                    .foregroundColor(isPlaying ? DaycoreTheme.accentLight : DaycoreTheme.textPrimary)
                    .lineLimit(1)
                
                Text(track.artist)
                    .font(.caption)
                    .foregroundColor(DaycoreTheme.textSecondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // 再生時間
            Text(formatDuration(track.duration))
                .font(.caption.monospaced())
                .foregroundColor(DaycoreTheme.textMuted)
            
            // 再生中インジケータ
            if isPlaying {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.caption)
                    .foregroundColor(DaycoreTheme.accent)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            isPlaying
            ? DaycoreTheme.accent.opacity(0.1)
            : Color.clear
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    
    // MARK: - Artwork Thumbnail
    
    private var artworkThumbnail: some View {
        Group {
            if let artwork = track.artwork,
               let image = artwork.image(at: CGSize(width: 50, height: 50)) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    DaycoreTheme.surfaceLight
                    Image(systemName: sourceIcon)
                        .font(.caption)
                        .foregroundColor(DaycoreTheme.accent)
                }
            }
        }
        .frame(width: 44, height: 44)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    private var sourceIcon: String {
        switch track.source {
        case .library: return "music.note"
        case .file: return "doc.fill"
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let mins = Int(duration) / 60
        let secs = Int(duration) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

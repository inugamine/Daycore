//
//  Track.swift
//  Daycore
//
//  Created by inugaminé on 2026/05/25.
//

import Foundation
import MediaPlayer

/// 再生対象となるトラックの情報
struct Track: Identifiable, Equatable {
    let id: String
    let title: String
    let artist: String
    let albumTitle: String?
    let duration: TimeInterval
    let artwork: MPMediaItemArtwork?
    let source: TrackSource
    
    enum TrackSource: Equatable {
        case library(MPMediaItem)
        case file(URL)
        
        static func == (lhs: TrackSource, rhs: TrackSource) -> Bool {
            switch (lhs, rhs) {
            case (.library(let a), .library(let b)):
                return a.persistentID == b.persistentID
            case (.file(let a), .file(let b)):
                return a == b
            default:
                return false
            }
        }
    }
    
    /// ミュージックライブラリのアイテムから生成
    init(mediaItem: MPMediaItem) {
        self.id = "\(mediaItem.persistentID)"
        self.title = mediaItem.title ?? "不明なタイトル"
        self.artist = mediaItem.artist ?? "不明なアーティスト"
        self.albumTitle = mediaItem.albumTitle
        self.duration = mediaItem.playbackDuration
        self.artwork = mediaItem.artwork
        self.source = .library(mediaItem)
    }
    
    /// ファイルURLから生成
    init(fileURL: URL, title: String? = nil, artist: String? = nil, duration: TimeInterval = 0) {
        self.id = fileURL.absoluteString
        self.title = title ?? fileURL.deletingPathExtension().lastPathComponent
        self.artist = artist ?? "不明なアーティスト"
        self.albumTitle = nil
        self.duration = duration
        self.artwork = nil
        self.source = .file(fileURL)
    }
}

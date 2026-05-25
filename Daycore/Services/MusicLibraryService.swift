//
//  MusicLibraryService.swift
//  Daycore
//
//  Created by inugaminé on 2026/05/25.
//

import Foundation
import Combine
import MediaPlayer
import AVFoundation

/// ミュージックライブラリへのアクセスとファイルインポートを管理
final class MusicLibraryService: ObservableObject {
    
    @Published var libraryTracks: [Track] = []
    @Published var importedTracks: [Track] = []
    @Published var authorizationStatus: MPMediaLibraryAuthorizationStatus = .notDetermined
    @Published var searchText: String = ""
    
    /// 検索結果（ライブラリ + インポート済み）
    var filteredTracks: [Track] {
        let all = libraryTracks + importedTracks
        guard !searchText.isEmpty else { return all }
        return all.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.artist.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    init() {
        checkAuthorization()
        loadImportedTracks()
    }
    
    // MARK: - Music Library
    
    /// ミュージックライブラリの認可状態を確認
    func checkAuthorization() {
        authorizationStatus = MPMediaLibrary.authorizationStatus()
    }
    
    /// ミュージックライブラリへのアクセスをリクエスト
    func requestAuthorization() {
        MPMediaLibrary.requestAuthorization { status in
            Task { @MainActor [weak self] in
                self?.authorizationStatus = status
                if status == .authorized {
                    self?.fetchLibrary()
                }
            }
        }
    }
    
    /// ミュージックライブラリから全曲を取得
    func fetchLibrary() {
        guard authorizationStatus == .authorized else {
            requestAuthorization()
            return
        }
        
        let query = MPMediaQuery.songs()
        query.addFilterPredicate(
            MPMediaPropertyPredicate(
                value: false,
                forProperty: MPMediaItemPropertyIsCloudItem
            )
        )
        
        libraryTracks = (query.items ?? []).map { Track(mediaItem: $0) }
    }
    
    // MARK: - File Import
    
    /// サポートするファイル形式
    static let supportedTypes = [
        "public.audio",
        "public.mp3",
        "public.mpeg-4-audio",
        "com.apple.m4a-audio",
        "com.microsoft.waveform-audio",
        "public.aiff-audio",
        "org.xiph.flac"
    ]
    
    /// インポートされたファイルを処理して Track に変換
    func importFile(at url: URL) {
        let accessed = url.startAccessingSecurityScopedResource()
        
        // アプリのドキュメントディレクトリにコピー
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let importedDir = documentsURL.appendingPathComponent("Imported", isDirectory: true)
        
        // ディレクトリ作成
        try? FileManager.default.createDirectory(at: importedDir, withIntermediateDirectories: true)
        
        let destURL = importedDir.appendingPathComponent(url.lastPathComponent)
        
        do {
            // 既存ファイルがあれば削除
            if FileManager.default.fileExists(atPath: destURL.path) {
                try FileManager.default.removeItem(at: destURL)
            }
            try FileManager.default.copyItem(at: url, to: destURL)
            
            if accessed { url.stopAccessingSecurityScopedResource() }
            
            // メタデータ取得
            let asset = AVURLAsset(url: destURL)
            let duration = CMTimeGetSeconds(asset.duration)
            
            // メタデータからタイトル・アーティストを抽出
            var title: String?
            var artist: String?
            
            for item in asset.commonMetadata {
                switch item.commonKey {
                case .commonKeyTitle:
                    title = item.stringValue
                case .commonKeyArtist:
                    artist = item.stringValue
                default:
                    break
                }
            }
            
            let track = Track(
                fileURL: destURL,
                title: title,
                artist: artist,
                duration: duration
            )
            
            // 重複チェック
            if !importedTracks.contains(where: { $0.id == track.id }) {
                importedTracks.append(track)
                saveImportedTrackPaths()
            }
            
        } catch {
            if accessed { url.stopAccessingSecurityScopedResource() }
            print("[MusicLibrary] インポート失敗: \(error)")
        }
    }
    
    /// インポート済みファイルの削除
    func removeImportedTrack(_ track: Track) {
        if case .file(let url) = track.source {
            try? FileManager.default.removeItem(at: url)
        }
        importedTracks.removeAll { $0.id == track.id }
        saveImportedTrackPaths()
    }
    
    // MARK: - Persistence
    
    private let importedPathsKey = "daycore_imported_paths"
    
    /// インポート済みファイルパスを保存
    private func saveImportedTrackPaths() {
        let paths = importedTracks.compactMap { track -> String? in
            if case .file(let url) = track.source {
                return url.path
            }
            return nil
        }
        UserDefaults.standard.set(paths, forKey: importedPathsKey)
    }
    
    /// インポート済みファイルを復元
    private func loadImportedTracks() {
        guard let paths = UserDefaults.standard.stringArray(forKey: importedPathsKey) else { return }
        
        for path in paths {
            let url = URL(fileURLWithPath: path)
            guard FileManager.default.fileExists(atPath: path) else { continue }
            
            let asset = AVURLAsset(url: url)
            let duration = CMTimeGetSeconds(asset.duration)
            
            var title: String?
            var artist: String?
            for item in asset.commonMetadata {
                switch item.commonKey {
                case .commonKeyTitle: title = item.stringValue
                case .commonKeyArtist: artist = item.stringValue
                default: break
                }
            }
            
            let track = Track(fileURL: url, title: title, artist: artist, duration: duration)
            importedTracks.append(track)
        }
    }
}

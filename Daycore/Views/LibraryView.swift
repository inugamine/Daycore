//
//  LibraryView.swift
//  Daycore
//
//  Created by inugaminé on 2026/05/25.
//

import SwiftUI
import UniformTypeIdentifiers
import MediaPlayer

/// ミュージックライブラリ & ファイルインポート画面
struct LibraryView: View {
    @ObservedObject var viewModel: PlayerViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = 0
    @State private var showingFileImporter = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                DaycoreTheme.background
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // タブ切り替え
                    tabSelector
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                    
                    // 検索バー
                    searchBar
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    
                    // コンテンツ
                    if selectedTab == 0 {
                        libraryContent
                    } else {
                        importedContent
                    }
                }
            }
            .navigationTitle("ライブラリ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("閉じる") { dismiss() }
                        .foregroundColor(DaycoreTheme.accent)
                }
                
                if selectedTab == 1 {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showingFileImporter = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(DaycoreTheme.accent)
                        }
                    }
                }
            }
            .fileImporter(
                isPresented: $showingFileImporter,
                allowedContentTypes: [.audio, .mp3, .mpeg4Audio, .wav, .aiff],
                allowsMultipleSelection: true
            ) { result in
                switch result {
                case .success(let urls):
                    for url in urls {
                        viewModel.musicLibrary.importFile(at: url)
                    }
                case .failure(let error):
                    print("[LibraryView] インポートエラー: \(error)")
                }
            }
        }
    }
    
    // MARK: - Tab Selector
    
    private var tabSelector: some View {
        HStack(spacing: 0) {
            tabButton("ミュージック", icon: "music.note", index: 0)
            tabButton("インポート", icon: "folder.fill", index: 1)
        }
        .background(DaycoreTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    
    private func tabButton(_ title: String, icon: String, index: Int) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab = index
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.subheadline.bold())
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                selectedTab == index
                ? DaycoreTheme.accent.opacity(0.3)
                : Color.clear
            )
            .foregroundColor(
                selectedTab == index
                ? DaycoreTheme.accentLight
                : DaycoreTheme.textSecondary
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    
    // MARK: - Search Bar
    
    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(DaycoreTheme.textMuted)
            
            TextField("曲名・アーティスト名で検索", text: $viewModel.musicLibrary.searchText)
                .foregroundColor(DaycoreTheme.textPrimary)
                .autocorrectionDisabled()
            
            if !viewModel.musicLibrary.searchText.isEmpty {
                Button {
                    viewModel.musicLibrary.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(DaycoreTheme.textMuted)
                }
            }
        }
        .padding(10)
        .background(DaycoreTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    
    // MARK: - Library Content
    
    private var libraryContent: some View {
        Group {
            switch viewModel.musicLibrary.authorizationStatus {
            case .authorized:
                trackList(viewModel.musicLibrary.filteredTracks.filter {
                    if case .library = $0.source { return true }
                    return false
                })
            case .notDetermined:
                permissionRequest
            default:
                permissionDenied
            }
        }
    }
    
    private var permissionRequest: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "lock.shield")
                .font(.system(size: 48))
                .foregroundColor(DaycoreTheme.accent)
            
            Text("ミュージックライブラリへのアクセスが必要です")
                .font(.headline)
                .foregroundColor(DaycoreTheme.textPrimary)
                .multilineTextAlignment(.center)
            
            Button {
                viewModel.musicLibrary.requestAuthorization()
            } label: {
                Text("アクセスを許可")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(DaycoreTheme.accentGradient)
                    .clipShape(Capsule())
            }
            Spacer()
        }
    }
    
    private var permissionDenied: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            
            Text("アクセスが拒否されています")
                .font(.headline)
                .foregroundColor(DaycoreTheme.textPrimary)
            
            Text("設定アプリからミュージックライブラリのアクセスを許可してください")
                .font(.subheadline)
                .foregroundColor(DaycoreTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
    }
    
    // MARK: - Imported Content
    
    private var importedContent: some View {
        Group {
            let imported = viewModel.musicLibrary.importedTracks
            if imported.isEmpty {
                importEmptyState
            } else {
                trackList(imported, canDelete: true)
            }
        }
    }
    
    private var importEmptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "square.and.arrow.down")
                .font(.system(size: 48))
                .foregroundColor(DaycoreTheme.accent)
            
            Text("音楽ファイルをインポート")
                .font(.headline)
                .foregroundColor(DaycoreTheme.textPrimary)
            
            Text("MP3, M4A, WAV, AIFF, FLAC に対応")
                .font(.subheadline)
                .foregroundColor(DaycoreTheme.textSecondary)
            
            Button {
                showingFileImporter = true
            } label: {
                Label("ファイルを選択", systemImage: "folder.badge.plus")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(DaycoreTheme.accentGradient)
                    .clipShape(Capsule())
            }
            Spacer()
        }
    }
    
    // MARK: - Track List
    
    private func trackList(_ tracks: [Track], canDelete: Bool = false) -> some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                ForEach(tracks) { track in
                    TrackRow(track: track, isPlaying: viewModel.currentTrack == track)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            viewModel.selectTrack(track)
                            dismiss()
                        }
                        .contextMenu {
                            if canDelete {
                                Button(role: .destructive) {
                                    viewModel.musicLibrary.removeImportedTrack(track)
                                } label: {
                                    Label("削除", systemImage: "trash")
                                }
                            }
                        }
                }
            }
            .padding(.horizontal, 16)
        }
    }
}

//
//  ContentView.swift
//  Daycore
//
//  Created by inugaminé on 2026/05/25.
//

import SwiftUI

/// メイン画面：プレーヤー + ライブラリシート
struct ContentView: View {
    @StateObject private var viewModel = PlayerViewModel()
    @State private var showingPlayer = false
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // プレーヤー画面
            PlayerView(viewModel: viewModel)
            
            // ミニプレーヤーバー（ライブラリ表示中に見えるように）
            // 現在の構成ではプレーヤーが常に見えるので不要だが、
            // 将来的にタブ構成にした場合に使える
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $viewModel.showingLibrary) {
            LibraryView(viewModel: viewModel)
                .preferredColorScheme(.dark)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    viewModel.showingLibrary = true
                } label: {
                    Image(systemName: "music.note.list")
                        .foregroundColor(DaycoreTheme.accent)
                }
            }
        }
        .onAppear {
            viewModel.setupRemoteCommands()
            viewModel.musicLibrary.fetchLibrary()
        }
    }
}

#Preview {
    ContentView()
}

//
//  ContentView.swift
//  Daycore
//
//  Created by inugaminé on 2026/05/25.
//

import SwiftUI

/// メイン画面：iPhone ではシート表示、iPad では2ペインレイアウト
struct ContentView: View {
    @StateObject private var viewModel = PlayerViewModel()
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                // iPad / 大画面: 2ペインレイアウト
                iPadLayout
            } else {
                // iPhone / コンパクト: 従来のシート表示
                iPhoneLayout
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            viewModel.setupRemoteCommands()
            viewModel.musicLibrary.fetchLibrary()
        }
    }
    
    // MARK: - iPhone Layout
    
    private var iPhoneLayout: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                PlayerView(viewModel: viewModel)
            }
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
        }
    }
    
    // MARK: - iPad Layout (2ペイン)
    
    private var iPadLayout: some View {
        HStack(spacing: 0) {
            // 左ペイン: ライブラリ
            LibraryView(viewModel: viewModel)
                .frame(minWidth: 320, maxWidth: 420)
            
            Divider()
                .background(DaycoreTheme.divider)
            
            // 右ペイン: プレーヤー
            PlayerView(viewModel: viewModel)
                .frame(maxWidth: .infinity)
        }
    }
}

#Preview {
    ContentView()
}

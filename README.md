# Daycore

iPhone の音楽ファイルを読み込んで BPM やピッチを変更し、Daycore に特化した音楽再生アプリ。

## 機能

- **Daycore 再生**: テンポとピッチをリアルタイムで変更
- **プリセット**: Original / Daycore Soft / Daycore / Daycore Deep / Nightcore
- **Speed / Pitch スライダー**: 手動で細かく調整可能
- **ミュージックライブラリ対応**: iPhone 内の曲を直接再生
- **ファイルインポート**: MP3, M4A, WAV, AIFF, FLAC をインポート可能
- **ロック画面コントロール**: Now Playing 対応

## 技術スタック

- Swift / SwiftUI
- AVAudioEngine + AVAudioUnitTimePitch（リアルタイム音声処理）
- MediaPlayer Framework（ミュージックライブラリ）
- UIDocumentPicker（ファイルインポート）

## セットアップ

### 1. Info.plist に以下のキーを追加

Xcode でプロジェクトの **Info** タブを開き、以下のキーを追加してください:

| Key | Value |
|-----|-------|
| `NSAppleMusicUsageDescription` | `ミュージックライブラリの楽曲を Daycore で再生するために使用します` |

### 2. Background Modes を有効化

1. プロジェクト設定 → **Signing & Capabilities**
2. **+ Capability** → **Background Modes** を追加
3. **Audio, AirPlay, and Picture in Picture** にチェック

### 3. ファイルを Xcode に追加

新しく追加したファイルが Xcode のプロジェクトナビゲーターに表示されていない場合、
各ディレクトリを右クリック → **Add Files to "Daycore"** で追加してください。

## ファイル構成

```
Daycore/
├── DaycoreApp.swift          # アプリエントリーポイント
├── ContentView.swift          # メイン画面
├── Models/
│   ├── Track.swift            # トラックモデル
│   └── DaycorePreset.swift    # プリセット定義
├── Services/
│   ├── AudioEngineService.swift    # 音声処理エンジン
│   └── MusicLibraryService.swift   # ライブラリ & インポート
├── ViewModels/
│   └── PlayerViewModel.swift  # プレーヤー ViewModel
├── Views/
│   ├── PlayerView.swift       # プレーヤー画面
│   ├── LibraryView.swift      # ライブラリ画面
│   └── Components/
│       ├── DaycoreSlider.swift     # カスタムスライダー
│       ├── TrackRow.swift          # トラック行
│       └── NowPlayingBar.swift     # ミニプレーヤーバー
└── Theme/
    └── DaycoreTheme.swift     # カラーテーマ
```

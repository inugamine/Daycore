//
//  NowPlayingService.swift
//  Daycore
//

import Foundation
import MediaPlayer
import UIKit

/// ロック画面 / コントロールセンター（Now Playing）の情報とリモートコマンドを一元管理する。
///
/// 更新経路が散らばると必ず「送り忘れ」が生まれ、
/// ロック画面だけが現実とズレた状態になる。窓口はこのクラスひとつに絞る。
@MainActor
final class NowPlayingService {

    /// リモートコマンドから呼び戻すハンドラ群
    struct CommandHandlers {
        let play: () -> Void
        let pause: () -> Void
        let togglePlayPause: () -> Void
        let nextTrack: () -> Void
        let previousTrack: () -> Void
        let seek: (TimeInterval) -> Void
    }

    /// Now Playing へ流し込む「今この瞬間」のスナップショット
    struct Snapshot {
        let trackID: String
        let title: String
        let artist: String
        let albumTitle: String?
        let duration: TimeInterval
        let elapsed: TimeInterval
        /// 実際の再生レート。停止中は 0。
        /// Daycore では 0.86 等の非等倍が入る。
        /// システムはこの値を使って画面上の時間を自前で進めるため、
        /// 実態とズレた値を送ると進捗バーだけが違う速度で走る。
        let rate: Float
        let artworkImage: UIImage?
    }

    /// MPMediaItemArtwork の生成は安くないので曲ごとにキャッシュする
    private var cachedArtwork: MPMediaItemArtwork?
    private var cachedArtworkTrackID: String?

    private var commandsRegistered = false

    // MARK: - Now Playing Info

    func update(_ snapshot: Snapshot) {
        var info: [String: Any] = [:]
        info[MPMediaItemPropertyTitle] = snapshot.title
        info[MPMediaItemPropertyArtist] = snapshot.artist
        if let album = snapshot.albumTitle {
            info[MPMediaItemPropertyAlbumTitle] = album
        }
        info[MPMediaItemPropertyPlaybackDuration] = snapshot.duration
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = snapshot.elapsed
        info[MPNowPlayingInfoPropertyPlaybackRate] = snapshot.rate
        // 「等倍は 1.0 である」と明示しておく。
        // これが無いとシステムが 0.86 を基準速度と誤解しうる。
        info[MPNowPlayingInfoPropertyDefaultPlaybackRate] = Float(1.0)
        info[MPNowPlayingInfoPropertyMediaType] = MPNowPlayingInfoMediaType.audio.rawValue

        if let artwork = artwork(for: snapshot) {
            info[MPMediaItemPropertyArtwork] = artwork
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    func clear() {
        cachedArtwork = nil
        cachedArtworkTrackID = nil
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    private func artwork(for snapshot: Snapshot) -> MPMediaItemArtwork? {
        guard let image = snapshot.artworkImage else {
            // 絵の無い曲では確実に捨てる。
            // 残しておくと前の曲のジャケットがロック画面に居座る。
            cachedArtwork = nil
            cachedArtworkTrackID = nil
            return nil
        }

        if let cachedArtwork, cachedArtworkTrackID == snapshot.trackID {
            return cachedArtwork
        }

        let artwork = Self.makeArtwork(image)
        cachedArtwork = artwork
        cachedArtworkTrackID = snapshot.trackID
        return artwork
    }

    // MARK: - Artwork

    /// MPMediaItemArtwork を nonisolated 文脈で生成するファクトリ。
    ///
    /// このプロジェクトは SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor なので、
    /// @MainActor のクラス内に普通にクロージャを書くと MainActor 隔離を継承する。
    /// requestHandler はシステムが任意のスレッドから呼ぶため、
    /// 隔離を持ったまま渡すと dispatch_assert_queue_fail でクラッシュする。
    /// static + nonisolated にして隔離の継承を断ち切るのが、この関数の唯一の目的。
    /// UIImage は不変なのでどのスレッドから返しても安全。
    nonisolated private static func makeArtwork(_ image: UIImage) -> MPMediaItemArtwork {
        MPMediaItemArtwork(boundsSize: image.size) { requestedSize in
            // ハンドラは「要求されたサイズの画像」を返す契約になっている。
            // 引数を無視して元画像をそのまま返すとシステムに黙って捨てられることがあり、
            // 「クラッシュはしないのにロック画面に絵が出ない」の典型的な原因になる。
            resized(image, to: requestedSize)
        }
    }

    /// 要求サイズちょうどの画像を作る。アスペクト比は保ったまま中央に収める。
    /// requestHandler から呼ばれるため nonisolated である必要がある。
    nonisolated private static func resized(_ image: UIImage, to size: CGSize) -> UIImage {
        guard size.width >= 1, size.height >= 1 else { return image }
        if image.size == size { return image }

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1      // size はすでにピクセル等価で渡ってくる
        format.opaque = false

        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            let scale = min(size.width / image.size.width,
                            size.height / image.size.height)
            let drawSize = CGSize(width: image.size.width * scale,
                                  height: image.size.height * scale)
            let origin = CGPoint(x: (size.width - drawSize.width) / 2,
                                 y: (size.height - drawSize.height) / 2)
            image.draw(in: CGRect(origin: origin, size: drawSize))
        }
    }

    // MARK: - Remote Commands

    func registerCommands(_ handlers: CommandHandlers) {
        // 二重登録ガード。
        // 呼び出し元は .onAppear なので画面が再表示されるたびに走る。
        // 素通しにするとハンドラが積み上がり「1回押すと2回効く」状態になる。
        guard !commandsRegistered else { return }
        commandsRegistered = true

        let center = MPRemoteCommandCenter.shared()

        center.playCommand.isEnabled = true
        center.playCommand.addTarget { _ in
            handlers.play()
            return .success
        }

        center.pauseCommand.isEnabled = true
        center.pauseCommand.addTarget { _ in
            handlers.pause()
            return .success
        }

        center.togglePlayPauseCommand.isEnabled = true
        center.togglePlayPauseCommand.addTarget { _ in
            handlers.togglePlayPause()
            return .success
        }

        center.nextTrackCommand.isEnabled = true
        center.nextTrackCommand.addTarget { _ in
            handlers.nextTrack()
            return .success
        }

        center.previousTrackCommand.isEnabled = true
        center.previousTrackCommand.addTarget { _ in
            handlers.previousTrack()
            return .success
        }

        center.changePlaybackPositionCommand.isEnabled = true
        center.changePlaybackPositionCommand.addTarget { event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            handlers.seek(event.positionTime)
            return .success
        }
    }
}

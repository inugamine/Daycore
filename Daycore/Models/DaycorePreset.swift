//
//  DaycorePreset.swift
//  Daycore
//
//  Created by inugaminé on 2026/05/25.
//

import Foundation

/// Daycore / Nightcore などのプリセット定義
struct AudioPreset: Identifiable, Equatable {
    let id: String
    let name: String
    let icon: String
    let rate: Float      // 再生速度 (1.0 = 通常)
    let pitch: Float     // ピッチ (semitones, 0.0 = 通常)
    
    static let original = AudioPreset(
        id: "original", name: "Original", icon: "waveform",
        rate: 1.0, pitch: 0.0
    )
    
    static let daycoreSoft = AudioPreset(
        id: "daycore_soft", name: "Daycore Soft", icon: "moon",
        rate: 0.85, pitch: -2.0
    )
    
    static let daycore = AudioPreset(
        id: "daycore", name: "Daycore", icon: "moon.fill",
        rate: 0.80, pitch: -3.0
    )
    
    static let daycoreDeep = AudioPreset(
        id: "daycore_deep", name: "Daycore Deep", icon: "moon.stars.fill",
        rate: 0.70, pitch: -5.0
    )
    
    static let nightcore = AudioPreset(
        id: "nightcore", name: "Nightcore", icon: "sun.max.fill",
        rate: 1.25, pitch: 3.0
    )
    
    static let allPresets: [AudioPreset] = [
        .original, .daycoreSoft, .daycore, .daycoreDeep, .nightcore
    ]
}

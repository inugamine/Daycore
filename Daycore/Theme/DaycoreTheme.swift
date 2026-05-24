//
//  DaycoreTheme.swift
//  Daycore
//
//  Created by inugaminé on 2026/05/25.
//

import SwiftUI

/// Daycore アプリのカラーテーマ
enum DaycoreTheme {
    // MARK: - Primary Colors
    static let background = Color(red: 0.06, green: 0.06, blue: 0.10)
    static let surface = Color(red: 0.10, green: 0.10, blue: 0.16)
    static let surfaceLight = Color(red: 0.14, green: 0.14, blue: 0.22)
    
    // MARK: - Accent Colors
    static let accent = Color(red: 0.45, green: 0.35, blue: 0.85)       // 深い紫
    static let accentLight = Color(red: 0.60, green: 0.50, blue: 1.0)
    static let accentGlow = Color(red: 0.45, green: 0.35, blue: 0.85).opacity(0.3)
    
    // MARK: - Text Colors
    static let textPrimary = Color.white
    static let textSecondary = Color(white: 0.6)
    static let textMuted = Color(white: 0.35)
    
    // MARK: - Semantic Colors
    static let sliderTrack = Color(white: 0.2)
    static let divider = Color(white: 0.15)
    
    // MARK: - Gradients
    static let backgroundGradient = LinearGradient(
        colors: [
            Color(red: 0.08, green: 0.05, blue: 0.15),
            Color(red: 0.04, green: 0.04, blue: 0.08)
        ],
        startPoint: .top,
        endPoint: .bottom
    )
    
    static let accentGradient = LinearGradient(
        colors: [accentLight, accent],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let artworkOverlay = LinearGradient(
        colors: [
            Color.black.opacity(0.0),
            Color.black.opacity(0.8)
        ],
        startPoint: .top,
        endPoint: .bottom
    )
}

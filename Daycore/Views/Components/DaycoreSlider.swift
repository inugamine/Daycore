//
//  DaycoreSlider.swift
//  Daycore
//
//  Created by inugaminé on 2026/05/25.
//

import SwiftUI

/// カスタムスライダー（Speed / Pitch 用）
struct DaycoreSlider: View {
    let label: String
    @Binding var value: Float
    let range: ClosedRange<Float>
    let icon: String
    let displayFormat: String
    
    var body: some View {
        VStack(spacing: 6) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.caption)
                        .foregroundColor(DaycoreTheme.accent)
                    
                    Text(label)
                        .font(.caption.bold())
                        .foregroundColor(DaycoreTheme.textSecondary)
                }
                
                Spacer()
                
                Text(String(format: displayFormat, value))
                    .font(.caption.monospaced())
                    .foregroundColor(DaycoreTheme.accentLight)
            }
            
            Slider(
                value: Binding(
                    get: { value },
                    set: { value = $0 }
                ),
                in: range
            )
            .tint(DaycoreTheme.accent)
        }
        .padding(12)
        .background(DaycoreTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

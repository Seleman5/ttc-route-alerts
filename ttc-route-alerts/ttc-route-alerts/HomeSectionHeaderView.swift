//
//  HomeSectionHeaderView.swift
//  ttc-route-alerts
//

import SwiftUI

struct HomeSectionHeaderView: View {
    let title: String
    let systemImage: String
    let tint: Color
    let accessoryText: String?

    init(title: String, systemImage: String, tint: Color, accessoryText: String? = nil) {
        self.title = title
        self.systemImage = systemImage
        self.tint = tint
        self.accessoryText = accessoryText
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 24, height: 24)
                .background(tint.opacity(0.12))
                .clipShape(Circle())

            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)

            Spacer(minLength: 8)

            if let accessoryText {
                Text(accessoryText)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.tertiarySystemGroupedBackground))
                    .clipShape(Capsule())
            }
        }
        .accessibilityElement(children: .combine)
    }
}

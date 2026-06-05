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
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 18, height: 18)
                .background(tint.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: 5))

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

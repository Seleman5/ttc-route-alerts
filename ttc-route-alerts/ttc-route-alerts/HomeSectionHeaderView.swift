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
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 17, height: 17)
                .background(tint.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 5))

            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)

            Spacer(minLength: 8)

            if let accessoryText {
                Text(accessoryText)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AppDesign.insetBackground)
                    .clipShape(Capsule())
            }
        }
        .accessibilityElement(children: .combine)
    }
}

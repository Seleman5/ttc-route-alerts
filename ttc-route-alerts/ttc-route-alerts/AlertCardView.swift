//
//  AlertCardView.swift
//  ttc-route-alerts
//

import SwiftUI

struct AlertCardView: View {
    let alertText: String
    let severity: AlertSeverity
    let lastUpdatedText: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 3)
                .fill(severity.textColor)
                .frame(width: 5)

            VStack(alignment: .leading, spacing: 10) {
                StatusBadgeView(severity: severity)

                Text(alertText)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Last successful update: \(lastUpdatedText)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(15)
        .background(AppDesign.cardBackground)
        .overlay {
            RoundedRectangle(cornerRadius: AppDesign.smallRadius)
                .stroke(severity.backgroundColor, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: AppDesign.smallRadius))
        .shadow(color: AppDesign.softShadow, radius: 10, x: 0, y: 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(severity.rawValue): \(alertText). Last successful update: \(lastUpdatedText)")
    }
}

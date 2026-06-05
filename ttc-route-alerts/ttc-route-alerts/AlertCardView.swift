//
//  AlertCardView.swift
//  ttc-route-alerts
//

import SwiftUI

struct AlertCardView: View {
    let alertText: String
    let severity: AlertSeverity

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
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(15)
        .background(Color(.secondarySystemGroupedBackground))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(severity.backgroundColor, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(severity.rawValue): \(alertText)")
    }
}

//
//  AddRouteFormView.swift
//  ttc-route-alerts
//

import SwiftUI

struct AddRouteFormView: View {
    @Binding var selectedRouteType: RouteType
    @Binding var routeNumberInput: String
    @Binding var routeNicknameInput: String

    let routeFormErrorMessage: String?
    let editingRouteID: UUID?
    let filteredSuggestedRoutes: [SuggestedRoute]
    let ttcRed: Color
    let onSave: () -> Void
    let onCancel: () -> Void
    let onSelectSuggestion: (SuggestedRoute) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HomeSectionHeaderView(
                title: editingRouteID == nil ? "Add Route" : "Edit Route",
                systemImage: editingRouteID == nil ? "plus" : "pencil",
                tint: ttcRed
            )

            Picker("Route Type", selection: $selectedRouteType) {
                ForEach(RouteType.allCases) { routeType in
                    Text(routeType.rawValue)
                        .tag(routeType)
                }
            }
            .pickerStyle(.segmented)

            TextField("Route number or name, like 1, 34, or 501", text: $routeNumberInput)
                .textInputAutocapitalization(.words)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(AppDesign.fieldBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppDesign.smallRadius))

            if let routeFormErrorMessage {
                Text(routeFormErrorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            TextField("Optional nickname, like Queen", text: $routeNicknameInput)
                .textInputAutocapitalization(.words)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(AppDesign.fieldBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppDesign.smallRadius))

            if !visibleSuggestedRoutes.isEmpty {
                routeSuggestionsSection
            }

            Divider()
                .padding(.vertical, 2)

            Button {
                onSave()
            } label: {
                Text(editingRouteID == nil ? "Add Route" : "Save Changes")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .foregroundStyle(.white)
                    .background(ttcRed)
                    .clipShape(RoundedRectangle(cornerRadius: AppDesign.smallRadius))
                    .shadow(color: ttcRed.opacity(0.18), radius: 8, x: 0, y: 3)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(editingRouteID == nil ? "Add route" : "Save changes")
            .accessibilityHint(editingRouteID == nil ? "Adds the selected TTC route to your saved routes." : "Saves changes to this TTC route.")

            if editingRouteID != nil {
                Button {
                    onCancel()
                } label: {
                    Text("Cancel")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .foregroundStyle(ttcRed)
                        .background(ttcRed.opacity(0.10))
                        .overlay {
                            RoundedRectangle(cornerRadius: AppDesign.smallRadius)
                                .stroke(ttcRed.opacity(0.18), lineWidth: 1)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: AppDesign.smallRadius))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .appCardStyle()
    }

    var routeSuggestionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Suggested Routes")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            ForEach(visibleSuggestedRoutes) { suggestion in
                Button {
                    onSelectSuggestion(suggestion)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(suggestion.displayName)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)

                            Text(suggestion.routeType.rawValue)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(ttcRed)
                    }
                    .padding(12)
                    .background(AppDesign.fieldBackground)
                    .clipShape(RoundedRectangle(cornerRadius: AppDesign.smallRadius))
                }
                .buttonStyle(.plain)
            }
        }
    }

    var visibleSuggestedRoutes: [SuggestedRoute] {
        Array(filteredSuggestedRoutes.prefix(6))
    }
}

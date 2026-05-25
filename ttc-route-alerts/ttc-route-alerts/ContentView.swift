//
//  ContentView.swift
//  ttc-route-alerts
//
//  Created by Seleman Shinwarie on 2026-05-19.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedRouteType = RouteType.subway
    @State private var routeNumberInput = ""
    @State private var routeNicknameInput = ""
    @State private var savedRoutes = ContentView.loadRoutes()
    @State private var ttcAlerts: [String] = []
    @State private var lastUpdatedDate = ContentView.loadLastUpdatedDate()
    @State private var isRefreshing = false
    @State private var refreshErrorMessage: String?
    @State private var editingRouteID: UUID?

    static let savedRoutesKey = "savedRoutes"
    static let lastUpdatedKey = "lastUpdated"
    static let starterRoutes = [
        TTCAlertRoute(name: "1", status: "No major issues", routeType: .subway, routeNumber: "1", nickname: "Yonge-University"),
        TTCAlertRoute(name: "32", status: "Delay reported", routeType: .bus, routeNumber: "32", nickname: "Eglinton West")
    ]

    let ttcRed = Color(red: 0.85, green: 0.06, blue: 0.10)
    let appBackground = Color(red: 0.96, green: 0.96, blue: 0.95)

    var body: some View {
        NavigationStack {
            ZStack {
                appBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        headerSection
                        addRouteSection
                        routesSection
                    }
                    .padding(20)
                }
                .refreshable {
                    await refreshAlerts()
                }
            }
            .navigationTitle("My Routes")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task {
                            await refreshAlerts()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(isRefreshing)
                    .accessibilityLabel(isRefreshing ? "Refreshing alerts" : "Refresh alerts")
                }
            }
        }
        .tint(ttcRed)
        .task {
            await refreshAlerts()
        }
    }

    var headerSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text("TTC Route Alerts")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                Text("Track only the TTC routes you care about.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Last updated: \(lastUpdatedText)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if isRefreshing {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)

                        Text("Refreshing alerts...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if let refreshErrorMessage {
                VStack(alignment: .leading, spacing: 10) {
                    Text(refreshErrorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)

                    Button {
                        Task {
                            await refreshAlerts()
                        }
                    } label: {
                        Text("Retry")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white)
                    .background(ttcRed)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .disabled(isRefreshing)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.red.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }

    var addRouteSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(editingRouteID == nil ? "Add Route" : "Edit Route")
                .font(.headline)

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
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            TextField("Optional nickname, like Queen", text: $routeNicknameInput)
                .textInputAutocapitalization(.words)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            routeSuggestionsSection

            Button {
                saveRouteForm()
            } label: {
                Text(editingRouteID == nil ? "Add Route" : "Save Changes")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .background(ttcRed)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            if editingRouteID != nil {
                Button {
                    clearRouteForm()
                } label: {
                    Text("Cancel")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
                .foregroundStyle(ttcRed)
                .background(ttcRed.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(16)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.06), radius: 14, x: 0, y: 6)
    }

    var routeSuggestionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Suggested Routes")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            ForEach(filteredSuggestedRoutes) { suggestion in
                Button {
                    selectSuggestedRoute(suggestion)
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
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
    }

    var routesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Saved Routes")
                .font(.headline)

            if savedRoutes.isEmpty {
                EmptyRoutesView(ttcRed: ttcRed)
            } else {
                List {
                    ForEach(savedRoutes) { route in
                        NavigationLink {
                            RouteDetailView(route: route, severity: routeSeverity(for: route), alerts: matchingAlerts(for: route), lastUpdatedText: lastUpdatedText, ttcRed: ttcRed, appBackground: appBackground)
                        } label: {
                            RouteCard(route: route, severity: routeSeverity(for: route), ttcRed: ttcRed)
                        }
                        .buttonStyle(.plain)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                            .listRowBackground(Color.clear)
                            .swipeActions {
                                Button(role: .destructive) {
                                    deleteRoute(route)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }

                                Button {
                                    startEditing(route)
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(ttcRed)
                            }
                    }
                    .onDelete(perform: deleteRoutes)
                }
                .listStyle(.plain)
                .scrollDisabled(true)
                .frame(height: CGFloat(savedRoutes.count) * 108)

                Text("Swipe left to edit or remove routes")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    var lastUpdatedText: String {
        guard let lastUpdatedDate else {
            return "Not updated yet"
        }

        return TimeFormatter.lastUpdatedText(for: lastUpdatedDate)
    }

    var filteredSuggestedRoutes: [SuggestedRoute] {
        let searchText = routeNumberInput.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if searchText.isEmpty {
            return RouteSuggestion.suggestedRoutes.filter { suggestion in
                suggestion.routeType == selectedRouteType
            }
        }

        return RouteSuggestion.suggestedRoutes.filter { suggestion in
            suggestion.matches(searchText)
        }
    }

    func selectSuggestedRoute(_ suggestion: SuggestedRoute) {
        selectedRouteType = suggestion.routeType
        routeNumberInput = suggestion.routeNumber
        routeNicknameInput = suggestion.nickname
    }

    func saveRouteForm() {
        if editingRouteID == nil {
            addRoute()
        } else {
            saveEditedRoute()
        }
    }

    func routeFromForm(id: UUID = UUID(), status: String = "Checking status...") -> TTCAlertRoute? {
        let cleanedRouteNumber = routeNumberInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedNickname = routeNicknameInput.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanedRouteNumber.isEmpty else {
            return nil
        }

        return TTCAlertRoute(
            id: id,
            name: cleanedRouteNumber,
            status: status,
            routeType: selectedRouteType,
            routeNumber: cleanedRouteNumber,
            nickname: cleanedNickname.isEmpty ? nil : cleanedNickname
        )
    }

    func addRoute() {
        guard let newRoute = routeFromForm() else {
            return
        }

        guard !routeAlreadySaved(newRoute) else {
            return
        }

        savedRoutes.append(newRoute)
        saveRoutes()
        clearRouteForm()
    }

    func startEditing(_ route: TTCAlertRoute) {
        editingRouteID = route.id
        selectedRouteType = route.routeType ?? .subway
        routeNumberInput = route.routeNumber ?? route.name
        routeNicknameInput = route.nickname ?? ""
    }

    func saveEditedRoute() {
        guard let editingRouteID,
              let routeIndex = savedRoutes.firstIndex(where: { $0.id == editingRouteID }) else {
            clearRouteForm()
            return
        }

        let currentRoute = savedRoutes[routeIndex]

        guard let editedRoute = routeFromForm(id: currentRoute.id, status: currentRoute.status) else {
            return
        }

        guard !routeAlreadySaved(editedRoute, excludingRouteID: editingRouteID) else {
            return
        }

        savedRoutes[routeIndex] = editedRoute
        saveRoutes()
        clearRouteForm()
    }

    func clearRouteForm() {
        editingRouteID = nil
        selectedRouteType = .subway
        routeNumberInput = ""
        routeNicknameInput = ""
    }

    func routeAlreadySaved(_ newRoute: TTCAlertRoute, excludingRouteID: UUID? = nil) -> Bool {
        savedRoutes.contains { savedRoute in
            if savedRoute.id == excludingRouteID {
                return false
            }

            let sameDisplayName = savedRoute.displayName.lowercased() == newRoute.displayName.lowercased()
            let sameRouteType = savedRoute.routeType == nil || savedRoute.routeType == newRoute.routeType
            let sameRouteNumber = RouteMatcher.routeNumber(for: savedRoute) == RouteMatcher.routeNumber(for: newRoute)

            return sameDisplayName || (sameRouteType && sameRouteNumber)
        }
    }

    func deleteRoutes(at offsets: IndexSet) {
        let deletedRouteIDs = offsets.map { savedRoutes[$0].id }
        savedRoutes.remove(atOffsets: offsets)
        saveRoutes()

        if let editingRouteID, deletedRouteIDs.contains(editingRouteID) {
            clearRouteForm()
        }
    }

    func deleteRoute(_ route: TTCAlertRoute) {
        savedRoutes.removeAll { savedRoute in
            savedRoute.id == route.id
        }
        saveRoutes()

        if editingRouteID == route.id {
            clearRouteForm()
        }
    }

    func refreshAlerts() async {
        guard !isRefreshing else {
            return
        }

        isRefreshing = true
        refreshErrorMessage = nil

        do {
            ttcAlerts = try await TTCAlertsService().fetchAlertsFeed()
            lastUpdatedDate = Date()
            saveLastUpdatedDate()
        } catch {
            refreshErrorMessage = "Could not refresh TTC alerts. Please try again."
            print("Could not refresh TTC alerts: \(error.localizedDescription)")
        }

        isRefreshing = false
    }

    func matchingAlerts(for route: TTCAlertRoute) -> [String] {
        return ttcAlerts.filter { alert in
            RouteMatcher.matches(alert, route: route)
        }
    }

    func routeSeverity(for route: TTCAlertRoute) -> AlertSeverity {
        AlertSeverity.strongestSeverity(in: matchingAlerts(for: route))
    }

    static func loadRoutes() -> [TTCAlertRoute] {
        guard let savedData = UserDefaults.standard.data(forKey: savedRoutesKey) else {
            return starterRoutes
        }

        do {
            return try JSONDecoder().decode([TTCAlertRoute].self, from: savedData)
        } catch {
            return starterRoutes
        }
    }

    static func loadLastUpdatedDate() -> Date? {
        UserDefaults.standard.object(forKey: lastUpdatedKey) as? Date
    }

    func saveRoutes() {
        do {
            let encodedRoutes = try JSONEncoder().encode(savedRoutes)
            UserDefaults.standard.set(encodedRoutes, forKey: ContentView.savedRoutesKey)
        } catch {
            print("Could not save routes")
        }
    }

    func saveLastUpdatedDate() {
        UserDefaults.standard.set(lastUpdatedDate, forKey: ContentView.lastUpdatedKey)
    }
}

#Preview {
    ContentView()
}

struct EmptyRoutesView: View {
    let ttcRed: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Circle()
                .fill(ttcRed.opacity(0.12))
                .frame(width: 48, height: 48)
                .overlay {
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(ttcRed)
                }

            Text("No saved routes yet")
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(.primary)

            Text("Add a subway, bus, or streetcar route above to start tracking TTC alerts.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 5)
    }
}

struct RouteCard: View {
    let route: TTCAlertRoute
    let severity: AlertSeverity
    let ttcRed: Color

    var body: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(ttcRed)
                .frame(width: 42, height: 42)
                .overlay {
                    Image(systemName: "tram.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                }

            VStack(alignment: .leading, spacing: 8) {
                Text(route.displayName)
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(.primary)

                StatusBadge(severity: severity)
            }

            Spacer()
        }
        .padding(16)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 5)
    }
}

struct RouteDetailView: View {
    let route: TTCAlertRoute
    let severity: AlertSeverity
    let alerts: [String]
    let lastUpdatedText: String
    let ttcRed: Color
    let appBackground: Color

    var body: some View {
        ZStack {
            appBackground
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    detailHeader
                    lastUpdatedSection
                    alertsSection
                }
                .padding(20)
            }
        }
        .navigationTitle(route.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }

    var detailHeader: some View {
        VStack(alignment: .leading, spacing: 14) {
            Circle()
                .fill(ttcRed)
                .frame(width: 54, height: 54)
                .overlay {
                    Image(systemName: "tram.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white)
                }

            Text(route.displayName)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)

            StatusBadge(severity: severity)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.06), radius: 14, x: 0, y: 6)
    }

    var lastUpdatedSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Last Updated")
                .font(.headline)

            Text(lastUpdatedText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 5)
    }

    var alertsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("TTC Alerts")
                .font(.headline)

            if alerts.isEmpty {
                Text("No alerts for this route right now.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(alerts, id: \.self) { alert in
                    AlertCard(alertText: alert, severity: AlertSeverity.forAlertText(alert))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 5)
    }
}

struct AlertCard: View {
    let alertText: String
    let severity: AlertSeverity

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 3)
                .fill(severity.textColor)
                .frame(width: 5)

            VStack(alignment: .leading, spacing: 10) {
                StatusBadge(severity: severity)

                Text(alertText)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(severity.backgroundColor.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct StatusBadge: View {
    let severity: AlertSeverity

    var body: some View {
        Text(severity.rawValue)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(severity.textColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(severity.backgroundColor)
            .clipShape(Capsule())
    }
}

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

    static let savedRoutesKey = "savedRoutes"
    static let lastUpdatedKey = "lastUpdated"
    static let starterRoutes = [
        TTCAlertRoute(name: "1", status: "No major issues", routeType: .subway, routeNumber: "1", nickname: "Yonge-University"),
        TTCAlertRoute(name: "32", status: "Delay reported", routeType: .bus, routeNumber: "32", nickname: "Eglinton West")
    ]
    // Temporary starter dataset for route autocomplete.
    // Later, this should be replaced with a full TTC GTFS routes database.
    static let suggestedRoutes = [
        SuggestedRoute(routeType: .subway, routeNumber: "1", nickname: "Yonge-University"),
        SuggestedRoute(routeType: .subway, routeNumber: "2", nickname: "Bloor-Danforth"),
        SuggestedRoute(routeType: .subway, routeNumber: "4", nickname: "Sheppard"),
        SuggestedRoute(routeType: .streetcar, routeNumber: "501", nickname: "Queen"),
        SuggestedRoute(routeType: .streetcar, routeNumber: "504", nickname: "King"),
        SuggestedRoute(routeType: .streetcar, routeNumber: "505", nickname: "Dundas"),
        SuggestedRoute(routeType: .streetcar, routeNumber: "506", nickname: "Carlton"),
        SuggestedRoute(routeType: .streetcar, routeNumber: "509", nickname: "Harbourfront"),
        SuggestedRoute(routeType: .streetcar, routeNumber: "510", nickname: "Spadina"),
        SuggestedRoute(routeType: .streetcar, routeNumber: "511", nickname: "Bathurst"),
        SuggestedRoute(routeType: .streetcar, routeNumber: "512", nickname: "St Clair"),
        SuggestedRoute(routeType: .bus, routeNumber: "7", nickname: "Bathurst"),
        SuggestedRoute(routeType: .bus, routeNumber: "11", nickname: "Bayview"),
        SuggestedRoute(routeType: .bus, routeNumber: "12", nickname: "Kingston Road"),
        SuggestedRoute(routeType: .bus, routeNumber: "19", nickname: "Bay"),
        SuggestedRoute(routeType: .bus, routeNumber: "24", nickname: "Victoria Park"),
        SuggestedRoute(routeType: .bus, routeNumber: "25", nickname: "Don Mills"),
        SuggestedRoute(routeType: .bus, routeNumber: "29", nickname: "Dufferin"),
        SuggestedRoute(routeType: .bus, routeNumber: "32", nickname: "Eglinton West"),
        SuggestedRoute(routeType: .bus, routeNumber: "34", nickname: "Eglinton East"),
        SuggestedRoute(routeType: .bus, routeNumber: "35", nickname: "Jane"),
        SuggestedRoute(routeType: .bus, routeNumber: "36", nickname: "Finch West"),
        SuggestedRoute(routeType: .bus, routeNumber: "39", nickname: "Finch East"),
        SuggestedRoute(routeType: .bus, routeNumber: "41", nickname: "Keele"),
        SuggestedRoute(routeType: .bus, routeNumber: "43", nickname: "Kennedy"),
        SuggestedRoute(routeType: .bus, routeNumber: "45", nickname: "Kipling"),
        SuggestedRoute(routeType: .bus, routeNumber: "47", nickname: "Lansdowne"),
        SuggestedRoute(routeType: .bus, routeNumber: "52", nickname: "Lawrence West"),
        SuggestedRoute(routeType: .bus, routeNumber: "53", nickname: "Steeles East"),
        SuggestedRoute(routeType: .bus, routeNumber: "54", nickname: "Lawrence East"),
        SuggestedRoute(routeType: .bus, routeNumber: "60", nickname: "Steeles West"),
        SuggestedRoute(routeType: .bus, routeNumber: "63", nickname: "Ossington"),
        SuggestedRoute(routeType: .bus, routeNumber: "68", nickname: "Warden"),
        SuggestedRoute(routeType: .bus, routeNumber: "72", nickname: "Pape"),
        SuggestedRoute(routeType: .bus, routeNumber: "75", nickname: "Sherbourne"),
        SuggestedRoute(routeType: .bus, routeNumber: "84", nickname: "Sheppard West"),
        SuggestedRoute(routeType: .bus, routeNumber: "85", nickname: "Sheppard East"),
        SuggestedRoute(routeType: .bus, routeNumber: "86", nickname: "Scarborough"),
        SuggestedRoute(routeType: .bus, routeNumber: "89", nickname: "Weston"),
        SuggestedRoute(routeType: .bus, routeNumber: "94", nickname: "Wellesley"),
        SuggestedRoute(routeType: .bus, routeNumber: "95", nickname: "York Mills"),
        SuggestedRoute(routeType: .bus, routeNumber: "96", nickname: "Wilson"),
        SuggestedRoute(routeType: .bus, routeNumber: "97", nickname: "Yonge"),
        SuggestedRoute(routeType: .bus, routeNumber: "100", nickname: "Flemingdon Park"),
        SuggestedRoute(routeType: .bus, routeNumber: "116", nickname: "Morningside")
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
            Text("Add Route")
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
                addRoute()
            } label: {
                Text("Add Route")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .background(ttcRed)
            .clipShape(RoundedRectangle(cornerRadius: 12))
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
                    }
                    .onDelete(perform: deleteRoutes)
                }
                .listStyle(.plain)
                .scrollDisabled(true)
                .frame(height: CGFloat(savedRoutes.count) * 108)

                Text("Swipe left to remove routes")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    var lastUpdatedText: String {
        guard let lastUpdatedDate else {
            return "Not updated yet"
        }

        return lastUpdatedDate.formatted(date: .abbreviated, time: .shortened)
    }

    var filteredSuggestedRoutes: [SuggestedRoute] {
        let searchText = routeNumberInput.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if searchText.isEmpty {
            return ContentView.suggestedRoutes.filter { suggestion in
                suggestion.routeType == selectedRouteType
            }
        }

        return ContentView.suggestedRoutes.filter { suggestion in
            suggestion.matches(searchText)
        }
    }

    func selectSuggestedRoute(_ suggestion: SuggestedRoute) {
        selectedRouteType = suggestion.routeType
        routeNumberInput = suggestion.routeNumber
        routeNicknameInput = suggestion.nickname
    }

    func addRoute() {
        let cleanedRouteNumber = routeNumberInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedNickname = routeNicknameInput.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanedRouteNumber.isEmpty else {
            return
        }

        let newRoute = TTCAlertRoute(
            name: cleanedRouteNumber,
            status: "Checking status...",
            routeType: selectedRouteType,
            routeNumber: cleanedRouteNumber,
            nickname: cleanedNickname.isEmpty ? nil : cleanedNickname
        )

        guard !routeAlreadySaved(newRoute) else {
            return
        }

        savedRoutes.append(newRoute)
        saveRoutes()
        routeNumberInput = ""
        routeNicknameInput = ""
    }

    func routeAlreadySaved(_ newRoute: TTCAlertRoute) -> Bool {
        savedRoutes.contains { savedRoute in
            let sameDisplayName = savedRoute.displayName.lowercased() == newRoute.displayName.lowercased()
            let sameRouteType = savedRoute.routeType == nil || savedRoute.routeType == newRoute.routeType
            let sameRouteNumber = RouteMatcher.routeNumber(for: savedRoute) == RouteMatcher.routeNumber(for: newRoute)

            return sameDisplayName || (sameRouteType && sameRouteNumber)
        }
    }

    func deleteRoutes(at offsets: IndexSet) {
        savedRoutes.remove(atOffsets: offsets)
        saveRoutes()
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

struct SuggestedRoute: Identifiable {
    let routeType: RouteType
    let routeNumber: String
    let nickname: String

    var id: String {
        "\(routeType.rawValue)-\(routeNumber)"
    }

    var displayName: String {
        "\(typeLabel) \(routeNumber) - \(nickname)"
    }

    var typeLabel: String {
        if routeType == .subway {
            return "Subway Line"
        } else {
            return routeType.rawValue
        }
    }

    func matches(_ searchText: String) -> Bool {
        let searchableText = [
            routeType.rawValue,
            typeLabel,
            routeNumber,
            nickname,
            displayName
        ]
        .joined(separator: " ")
        .lowercased()

        return searchText
            .split(separator: " ")
            .allSatisfy { searchableText.contains($0) }
    }
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

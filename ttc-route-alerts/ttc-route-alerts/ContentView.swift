//
//  ContentView.swift
//  ttc-route-alerts
//
//  Created by Seleman Shinwarie on 2026-05-19.
//

import SwiftUI

enum RouteType: String, CaseIterable, Codable, Identifiable {
    case subway = "Subway"
    case bus = "Bus"
    case streetcar = "Streetcar"

    var id: String {
        rawValue
    }
}

enum AlertSeverity: String {
    case normal = "Normal"
    case minor = "Minor Alert"
    case major = "Major Alert"

    var priority: Int {
        switch self {
        case .normal:
            return 0
        case .minor:
            return 1
        case .major:
            return 2
        }
    }

    var textColor: Color {
        switch self {
        case .normal:
            return .green
        case .minor:
            return .orange
        case .major:
            return .red
        }
    }

    var backgroundColor: Color {
        switch self {
        case .normal:
            return Color.green.opacity(0.14)
        case .minor:
            return Color.orange.opacity(0.16)
        case .major:
            return Color.red.opacity(0.12)
        }
    }

    static func forAlertText(_ alertText: String) -> AlertSeverity {
        let lowercaseAlert = alertText.lowercased()
        let majorKeywords = ["suspended", "closure", "shuttle bus", "no service"]
        let minorKeywords = ["delay", "detour", "elevator", "escalator", "unavailable"]

        if majorKeywords.contains(where: { lowercaseAlert.contains($0) }) {
            return .major
        }

        if minorKeywords.contains(where: { lowercaseAlert.contains($0) }) {
            return .minor
        }

        return .minor
    }

    static func strongestSeverity(in alerts: [String]) -> AlertSeverity {
        guard !alerts.isEmpty else {
            return .normal
        }

        var strongestSeverity = AlertSeverity.minor

        for alert in alerts {
            let alertSeverity = AlertSeverity.forAlertText(alert)

            if alertSeverity.priority > strongestSeverity.priority {
                strongestSeverity = alertSeverity
            }
        }

        return strongestSeverity
    }
}

struct TTCAlertRoute: Identifiable, Codable {
    let id: UUID
    let name: String
    let status: String
    let routeType: RouteType?
    let routeNumber: String?
    let nickname: String?

    init(
        id: UUID = UUID(),
        name: String,
        status: String,
        routeType: RouteType? = nil,
        routeNumber: String? = nil,
        nickname: String? = nil
    ) {
        self.id = id
        self.name = name
        self.status = status
        self.routeType = routeType
        self.routeNumber = routeNumber
        self.nickname = nickname
    }

    var displayName: String {
        guard let routeType, let routeNumber, !routeNumber.isEmpty else {
            return name
        }

        let typeLabel: String

        if routeType == .subway {
            typeLabel = "Subway Line"
        } else {
            typeLabel = routeType.rawValue
        }

        let routeTitle = "\(typeLabel) \(routeNumber)"

        if let nickname, !nickname.isEmpty {
            return "\(routeTitle) - \(nickname)"
        } else {
            return routeTitle
        }
    }
}

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
            }
            .navigationTitle("My Routes")
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
                Button {
                    Task {
                        await refreshAlerts()
                    }
                } label: {
                    Label(isRefreshing ? "Refreshing" : "Refresh", systemImage: "arrow.clockwise")
                        .fontWeight(.semibold)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .background(isRefreshing ? Color.gray : ttcRed)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .disabled(isRefreshing)

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
            let sameRouteNumber = routeNumberForMatching(savedRoute) == routeNumberForMatching(newRoute)

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
        let routeSearchTerms = searchTerms(for: route)

        return ttcAlerts.filter { alert in
            let lowercaseAlert = alert.lowercased()
            let alertWords = words(in: lowercaseAlert)

            return routeSearchTerms.contains { searchTerm in
                if shouldMatchWholeWord(searchTerm) {
                    return alertWords.contains(searchTerm)
                } else {
                    return lowercaseAlert.contains(searchTerm)
                }
            }
        }
    }

    func routeSeverity(for route: TTCAlertRoute) -> AlertSeverity {
        AlertSeverity.strongestSeverity(in: matchingAlerts(for: route))
    }

    func searchTerms(for route: TTCAlertRoute) -> [String] {
        let lowercaseRouteName = route.displayName.lowercased()
        let routeNumber = routeNumberForMatching(route)
        let nickname = route.nickname?.lowercased()

        var searchTerms = [lowercaseRouteName, route.name.lowercased()]

        if let routeNumber {
            searchTerms.append(routeNumber)

            if route.routeType == .subway {
                searchTerms.append("line \(routeNumber)")
            } else {
                searchTerms.append("route \(routeNumber)")
            }
        }

        if let nickname, !nickname.isEmpty {
            searchTerms.append(nickname)
        }

        return Array(Set(searchTerms))
    }

    func routeNumberForMatching(_ route: TTCAlertRoute) -> String? {
        if let routeNumber = route.routeNumber?.lowercased(), !routeNumber.isEmpty {
            return routeNumber
        }

        return route.name
            .lowercased()
            .components(separatedBy: CharacterSet.decimalDigits.inverted)
            .first { !$0.isEmpty }
    }

    func shouldMatchWholeWord(_ searchTerm: String) -> Bool {
        searchTerm.allSatisfy { character in
            character.isLetter || character.isNumber
        }
    }

    func words(in text: String) -> [String] {
        text
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
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

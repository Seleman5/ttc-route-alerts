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

    static let savedRoutesKey = "savedRoutes"
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
            ttcAlerts = await TTCAlertsService().fetchAlertsFeed()
        }
    }

    var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TTC Route Alerts")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)

            Text("Track only the TTC routes you care about.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
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

            List {
                ForEach(savedRoutes) { route in
                    NavigationLink {
                        RouteDetailView(route: route, status: routeStatus(for: route), alerts: matchingAlerts(for: route), ttcRed: ttcRed, appBackground: appBackground)
                    } label: {
                        RouteCard(route: route, status: routeStatus(for: route), ttcRed: ttcRed)
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

    func routeStatus(for route: TTCAlertRoute) -> String {
        if matchingAlerts(for: route).isEmpty {
            return "No major issues"
        } else {
            return "Service Alert"
        }
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

    func saveRoutes() {
        do {
            let encodedRoutes = try JSONEncoder().encode(savedRoutes)
            UserDefaults.standard.set(encodedRoutes, forKey: ContentView.savedRoutesKey)
        } catch {
            print("Could not save routes")
        }
    }
}

#Preview {
    ContentView()
}

struct RouteCard: View {
    let route: TTCAlertRoute
    let status: String
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

                StatusBadge(status: status)
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
    let status: String
    let alerts: [String]
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

            StatusBadge(status: status)
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

            Text("A few minutes ago")
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
                    Text(alert)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
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

struct StatusBadge: View {
    let status: String

    var body: some View {
        Text(status)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(textColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(backgroundColor)
            .clipShape(Capsule())
    }

    var textColor: Color {
        if status.contains("Service Alert") {
            return .red
        } else if status.contains("No major") {
            return .green
        } else {
            return .secondary
        }
    }

    var backgroundColor: Color {
        if status.contains("Service Alert") {
            return Color.red.opacity(0.12)
        } else if status.contains("No major") {
            return Color.green.opacity(0.14)
        } else {
            return Color(.systemGray6)
        }
    }
}

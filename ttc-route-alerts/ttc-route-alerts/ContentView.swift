//
//  ContentView.swift
//  ttc-route-alerts
//
//  Created by Seleman Shinwarie on 2026-05-19.
//

import SwiftUI

struct ContentView: View {
    @AppStorage("notificationsEnabled") private var notificationsEnabled = false
    @AppStorage(RefreshPreference.storageKey) private var refreshPreference = RefreshPreference.manualOnly.rawValue
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedRouteType = RouteType.subway
    @State private var routeNumberInput = ""
    @State private var routeNicknameInput = ""
    @State private var savedRoutes = ContentView.loadRoutes()
    @State private var ttcAlerts: [TTCAlert] = ContentView.loadCachedAlerts()
    @State private var lastUpdatedDate = ContentView.loadLastUpdatedDate()
    @State private var isRefreshing = false
    @State private var refreshErrorMessage: String?
    @State private var routeFormErrorMessage: String?
    @State private var editingRouteID: UUID?
    @State private var routeSuggestions = RouteSuggestion.suggestedRoutes
    @State private var filteredSuggestedRoutesCache: [SuggestedRoute] = []
    @State private var routeAlertMatches: [UUID: [TTCAlert]] = [:]
    @State private var routeSeverities: [UUID: AlertSeverity] = [:]
    @State private var sentNotificationKeys: Set<String> = []
    @State private var autoRefreshTask: Task<Void, Never>?
    @ScaledMetric private var routeRowHeight = 108

    static let savedRoutesKey = "savedRoutes"
    static let cachedAlertsKey = "cachedTTCAlerts"
    static let lastUpdatedKey = "lastUpdated"
    static let starterRoutes = [
        TTCAlertRoute(name: "1", status: "No major issues", routeType: .subway, routeNumber: "1", nickname: "Yonge-University"),
        TTCAlertRoute(name: "32", status: "Delay reported", routeType: .bus, routeNumber: "32", nickname: "Eglinton West")
    ]

    let ttcRed = Color(red: 0.85, green: 0.06, blue: 0.10)
    let appBackground = Color(.systemGroupedBackground)

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
                    await refreshAlerts(shouldSendNotifications: true)
                }
            }
            .navigationTitle("My Routes")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    NavigationLink {
                        SettingsView(ttcRed: ttcRed, appBackground: appBackground)
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                    .accessibilityHint("Opens notification and refresh settings.")
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task {
                            await refreshAlerts(shouldSendNotifications: true)
                        }
                    } label: {
                        ZStack {
                            Image(systemName: "arrow.clockwise")
                                .opacity(isRefreshing ? 0 : 1)

                            ProgressView()
                                .controlSize(.small)
                                .opacity(isRefreshing ? 1 : 0)
                        }
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                    }
                    .disabled(isRefreshing)
                    .accessibilityLabel(isRefreshing ? "Refreshing alerts" : "Refresh alerts")
                    .accessibilityHint("Fetches the latest TTC alerts for your saved routes.")
                }
            }
        }
        .tint(ttcRed)
        .task {
            await refreshAlerts(shouldSendNotifications: false)
        }
        .onAppear {
            updateFilteredSuggestedRoutes()
            rebuildRouteAlertCache()
            startAutoRefreshIfNeeded()
        }
        .onDisappear {
            stopAutoRefresh()
        }
        .onChange(of: refreshPreference) { _, _ in
            startAutoRefreshIfNeeded()
            BackgroundAlertRefreshManager.scheduleBackgroundRefresh()
        }
        .onChange(of: routeNumberInput) { _, _ in
            updateFilteredSuggestedRoutes()
        }
        .onChange(of: selectedRouteType) { _, _ in
            updateFilteredSuggestedRoutes()
        }
        .onChange(of: scenePhase) { _, newScenePhase in
            if newScenePhase == .active {
                startAutoRefreshIfNeeded()
            } else {
                stopAutoRefresh()
            }
        }
    }

    var headerSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text("TTC Route Alerts")
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))
                    .foregroundStyle(.primary)

                Text("Track only the TTC routes you care about.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                Text("Last successful update: \(lastUpdatedText)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ZStack {
                    if isRefreshing {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
                .frame(width: 18, height: 18)
            }
            .frame(minHeight: 18, alignment: .leading)

            if let refreshErrorMessage {
                HStack(spacing: 10) {
                    Image(systemName: "wifi.exclamationmark")
                        .font(.caption)
                        .foregroundStyle(.orange)

                    Text(refreshErrorMessage)
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .lineLimit(2)

                    Spacer(minLength: 8)

                    Button {
                        Task {
                            await refreshAlerts(shouldSendNotifications: true)
                        }
                    } label: {
                        Text("Retry")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white)
                    .background(ttcRed)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .disabled(isRefreshing)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
        .animation(.easeInOut(duration: 0.2), value: isRefreshing)
        .animation(.easeInOut(duration: 0.2), value: refreshErrorMessage)
    }

    var addRouteSection: some View {
        AddRouteFormView(
            selectedRouteType: $selectedRouteType,
            routeNumberInput: $routeNumberInput,
            routeNicknameInput: $routeNicknameInput,
            routeFormErrorMessage: routeFormErrorMessage,
            editingRouteID: editingRouteID,
            filteredSuggestedRoutes: filteredSuggestedRoutes,
            ttcRed: ttcRed,
            onSave: saveRouteForm,
            onCancel: clearRouteForm,
            onSelectSuggestion: selectSuggestedRoute
        )
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
                            RouteCardView(route: route, severity: routeSeverity(for: route), ttcRed: ttcRed)
                        }
                        .buttonStyle(.plain)
                            .accessibilityHint("Opens details for \(route.displayName).")
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                            .listRowBackground(Color.clear)
                            .swipeActions {
                                Button(role: .destructive) {
                                    deleteRoute(route)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                .accessibilityLabel("Delete \(route.displayName)")
                                .accessibilityHint("Removes this route from your saved routes.")

                                Button {
                                    startEditing(route)
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(ttcRed)
                                .accessibilityLabel("Edit \(route.displayName)")
                                .accessibilityHint("Loads this route into the edit form.")
                            }
                    }
                    .onDelete(perform: deleteRoutes)
                }
                .listStyle(.plain)
                .scrollDisabled(true)
                .frame(height: CGFloat(savedRoutes.count) * routeRowHeight)

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
        filteredSuggestedRoutesCache
    }

    func updateFilteredSuggestedRoutes() {
        let searchText = routeNumberInput.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if searchText.isEmpty {
            filteredSuggestedRoutesCache = routeSuggestions.filter { suggestion in
                suggestion.routeType == selectedRouteType
            }
            return
        }

        filteredSuggestedRoutesCache = routeSuggestions.filter { suggestion in
            suggestion.matches(searchText)
        }
    }

    func selectSuggestedRoute(_ suggestion: SuggestedRoute) {
        selectedRouteType = suggestion.routeType
        routeNumberInput = suggestion.routeNumber
        routeNicknameInput = suggestion.nickname
        routeFormErrorMessage = nil
        updateFilteredSuggestedRoutes()
    }

    func saveRouteForm() {
        if editingRouteID == nil {
            addRoute()
        } else {
            saveEditedRoute()
        }
    }

    func routeFromForm(id: UUID = UUID(), status: String = "Checking status...") -> TTCAlertRoute? {
        let validationResult = RouteInputValidator.validateRoute(
            routeInput: routeNumberInput,
            nicknameInput: routeNicknameInput,
            selectedRouteType: selectedRouteType,
            id: id,
            status: status
        )

        guard let route = validationResult.route else {
            routeFormErrorMessage = validationResult.errorMessage
            return nil
        }

        return route
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
        rebuildRouteAlertCache()
        routeFormErrorMessage = nil
        clearRouteForm()
    }

    func startEditing(_ route: TTCAlertRoute) {
        editingRouteID = route.id
        selectedRouteType = route.routeType ?? .subway
        routeNumberInput = route.routeNumber ?? route.name
        routeNicknameInput = route.nickname ?? ""
        routeFormErrorMessage = nil
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
        rebuildRouteAlertCache()
        routeFormErrorMessage = nil
        clearRouteForm()
    }

    func clearRouteForm() {
        editingRouteID = nil
        selectedRouteType = .subway
        routeNumberInput = ""
        routeNicknameInput = ""
        routeFormErrorMessage = nil
        updateFilteredSuggestedRoutes()
    }

    func validationMessage(for routeType: RouteType) -> String {
        RouteInputValidator.validationMessage(for: routeType)
    }

    func routeAlreadySaved(_ newRoute: TTCAlertRoute, excludingRouteID: UUID? = nil) -> Bool {
        RouteInputValidator.routeAlreadySaved(
            newRoute,
            in: savedRoutes,
            excludingRouteID: excludingRouteID
        )
    }

    func deleteRoutes(at offsets: IndexSet) {
        let deletedRouteIDs = offsets.map { savedRoutes[$0].id }
        savedRoutes.remove(atOffsets: offsets)
        saveRoutes()
        rebuildRouteAlertCache()

        if let editingRouteID, deletedRouteIDs.contains(editingRouteID) {
            clearRouteForm()
        }
    }

    func deleteRoute(_ route: TTCAlertRoute) {
        savedRoutes.removeAll { savedRoute in
            savedRoute.id == route.id
        }
        saveRoutes()
        rebuildRouteAlertCache()

        if editingRouteID == route.id {
            clearRouteForm()
        }
    }

    func refreshAlerts(shouldSendNotifications: Bool = true) async {
        guard !isRefreshing else {
            return
        }

        isRefreshing = true
        refreshErrorMessage = nil

        do {
            ttcAlerts = try await TTCAlertsService().fetchAlertsFeed()
            lastUpdatedDate = Date()
            rebuildRouteAlertCache()
            saveCachedAlerts()
            saveLastUpdatedDate()

            if shouldSendNotifications {
                await sendNotificationsForAlertingRoutesIfNeeded()
            }
        } catch {
            refreshErrorMessage = cachedAlertsMessage
            print("Could not refresh TTC alerts: \(error.localizedDescription)")
        }

        isRefreshing = false
    }

    func startAutoRefreshIfNeeded() {
        stopAutoRefresh()

        guard scenePhase == .active,
              let selectedPreference = RefreshPreference(rawValue: refreshPreference),
              let refreshIntervalInSeconds = selectedPreference.refreshIntervalInSeconds else {
            return
        }

        let refreshIntervalInNanoseconds = UInt64(refreshIntervalInSeconds * 1_000_000_000)

        autoRefreshTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: refreshIntervalInNanoseconds)

                if Task.isCancelled {
                    return
                }

                await refreshAlerts(shouldSendNotifications: true)
            }
        }
    }

    func stopAutoRefresh() {
        autoRefreshTask?.cancel()
        autoRefreshTask = nil
    }

    func sendNotificationsForAlertingRoutesIfNeeded() async {
        guard notificationsEnabled else {
            return
        }

        for route in savedRoutes {
            let alerts = matchingAlerts(for: route)
            let severity = AlertSeverity.strongestSeverity(in: alerts.map(\.text))

            guard severity != .normal else {
                continue
            }

            let notificationKey = RouteAlertNotificationManager.notificationKey(
                for: route,
                severity: severity,
                alerts: alerts
            )

            guard !sentNotificationKeys.contains(notificationKey),
                  !RouteAlertNotificationManager.hasRecentlySentNotification(identifier: notificationKey) else {
                continue
            }

            let didScheduleNotification = await RouteAlertNotificationManager.scheduleRouteAlertNotification(
                for: route,
                severity: severity,
                identifier: notificationKey
            )

            if didScheduleNotification {
                sentNotificationKeys.insert(notificationKey)
            }
        }
    }

    func matchingAlerts(for route: TTCAlertRoute) -> [TTCAlert] {
        RouteAlertStatus.matchingAlerts(
            for: route,
            cachedAlerts: routeAlertMatches[route.id],
            allAlerts: ttcAlerts
        )
    }

    func routeSeverity(for route: TTCAlertRoute) -> AlertSeverity {
        if let cachedSeverity = routeSeverities[route.id] {
            return cachedSeverity
        }

        let alerts = matchingAlerts(for: route)
        return AlertSeverity.strongestSeverity(in: alerts.map(\.text))
    }

    func rebuildRouteAlertCache() {
        var newRouteAlertMatches: [UUID: [TTCAlert]] = [:]
        var newRouteSeverities: [UUID: AlertSeverity] = [:]

        for route in savedRoutes {
            let alerts = matchingAlertsWithoutCache(for: route)
            newRouteAlertMatches[route.id] = alerts
            newRouteSeverities[route.id] = AlertSeverity.strongestSeverity(in: alerts.map(\.text))
        }

        routeAlertMatches = newRouteAlertMatches
        routeSeverities = newRouteSeverities
    }

    func matchingAlertsWithoutCache(for route: TTCAlertRoute) -> [TTCAlert] {
        RouteAlertStatus.matchingAlerts(for: route, in: ttcAlerts)
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

    static func loadCachedAlerts() -> [TTCAlert] {
        guard let savedData = UserDefaults.standard.data(forKey: cachedAlertsKey) else {
            return []
        }

        do {
            return try JSONDecoder().decode([TTCAlert].self, from: savedData)
        } catch {
            return []
        }
    }

    var cachedAlertsMessage: String {
        if ttcAlerts.isEmpty {
            return "Couldn't refresh. No saved alerts yet."
        } else {
            return "Couldn't refresh. Showing last saved alerts."
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

    func saveCachedAlerts() {
        do {
            let encodedAlerts = try JSONEncoder().encode(ttcAlerts)
            UserDefaults.standard.set(encodedAlerts, forKey: ContentView.cachedAlertsKey)
        } catch {
            print("Could not save cached alerts")
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
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 5)
    }
}

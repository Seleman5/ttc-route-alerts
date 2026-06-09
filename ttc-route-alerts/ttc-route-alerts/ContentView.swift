//
//  ContentView.swift
//  ttc-route-alerts
//
//  Created by Seleman Shinwarie on 2026-05-19.
//

import CoreLocation
import SwiftUI

struct ContentView: View {
    private enum MainScreen: String, CaseIterable, Identifiable {
        case alerts = "Alerts"
        case nearby = "Nearby"

        var id: String {
            rawValue
        }
    }

    @AppStorage("notificationsEnabled") private var notificationsEnabled = false
    @AppStorage(RefreshPreference.storageKey) private var refreshPreference = RefreshPreference.manualOnly.rawValue
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var locationManager = NearbyLocationManager()
    @State private var selectedMainScreen = MainScreen.alerts
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
    @State private var routeArrivalStates: [UUID: SavedRouteArrivalState] = [:]
    @State private var routeArrivalCache: [UUID: SavedRouteArrivalCacheEntry] = [:]
    @State private var autoRefreshTask: Task<Void, Never>?
    @State private var routeArrivalTask: Task<Void, Never>?
    @ScaledMetric private var routeRowHeight = 138

    static let savedRoutesKey = "savedRoutes"
    static let cachedAlertsKey = "cachedTTCAlerts"
    static let lastUpdatedKey = "lastUpdated"
    static let starterRoutes = [
        TTCAlertRoute(name: "1", status: "No major issues", routeType: .subway, routeNumber: "1", nickname: "Yonge-University"),
        TTCAlertRoute(name: "32", status: "Delay reported", routeType: .bus, routeNumber: "32", nickname: "Eglinton West")
    ]

    let ttcRed = AppDesign.ttcRed
    let appBackground = AppDesign.appBackground
    let savedRouteArrivalService = SavedRouteArrivalService()
    let routeArrivalCacheDuration: TimeInterval = 60

    var body: some View {
        NavigationStack {
            ZStack {
                appBackground
                    .ignoresSafeArea()

                if selectedMainScreen == .alerts {
                    alertsScreen
                } else {
                    nearbyScreen
                }
            }
            .navigationTitle("TTC Route Alerts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    NavigationLink {
                        SettingsView(ttcRed: ttcRed, appBackground: appBackground)
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.body.weight(.semibold))
                    }
                    .accessibilityLabel("Settings")
                    .accessibilityHint("Opens notification and refresh settings.")
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    if selectedMainScreen == .alerts {
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
                        .font(.body.weight(.semibold))
                        .disabled(isRefreshing)
                        .accessibilityLabel(isRefreshing ? "Refreshing alerts" : "Refresh alerts")
                        .accessibilityHint("Fetches the latest TTC alerts for your saved routes.")
                    }
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
            requestSavedRouteLocationIfNeeded()
            refreshSavedRouteArrivalsIfPossible()
        }
        .onDisappear {
            stopAutoRefresh()
            routeArrivalTask?.cancel()
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
                requestSavedRouteLocationIfNeeded()
                refreshSavedRouteArrivalsIfPossible()
            } else {
                stopAutoRefresh()
            }
        }
        .onChange(of: selectedMainScreen) { _, newScreen in
            if newScreen == .alerts {
                requestSavedRouteLocationIfNeeded()
                refreshSavedRouteArrivalsIfPossible()
            }
        }
        .onReceive(locationManager.$currentLocation) { currentLocation in
            if currentLocation != nil {
                refreshSavedRouteArrivalsIfPossible(force: true)
            }
        }
    }

    var alertsScreen: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppDesign.sectionSpacing) {
                screenToggle
                headerSection
                addRouteSection
                routesSection
            }
            .padding(.horizontal, AppDesign.screenHorizontalPadding)
            .padding(.top, 12)
            .padding(.bottom, 48)
        }
        .safeAreaInset(edge: .bottom) {
            Color.clear
                .frame(height: 16)
        }
        .scrollDismissesKeyboard(.interactively)
        .refreshable {
            await refreshAlerts(shouldSendNotifications: true)
        }
    }

    var nearbyScreen: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppDesign.sectionSpacing) {
                screenToggle
                NearbyStopsView(locationManager: locationManager, ttcRed: ttcRed)
            }
            .padding(.horizontal, AppDesign.screenHorizontalPadding)
            .padding(.top, 12)
            .padding(.bottom, 48)
        }
        .safeAreaInset(edge: .bottom) {
            Color.clear
                .frame(height: 16)
        }
    }

    var screenToggle: some View {
        Picker("Screen", selection: $selectedMainScreen) {
            ForEach(MainScreen.allCases) { screen in
                Text(screen.rawValue).tag(screen)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityLabel("Main screen")
        .accessibilityHint("Switches between route alerts and nearby stops.")
    }

    var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("My Routes")
                            .font(.system(.title2, design: .rounded).weight(.bold))
                            .foregroundStyle(.primary)

                        Text("Track only the TTC routes you care about.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 12)

                    Text("\(savedRoutes.count)")
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .foregroundStyle(ttcRed)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(ttcRed.opacity(0.08))
                        .clipShape(Capsule())
                        .accessibilityLabel("\(savedRoutes.count) saved routes")
                }

                Divider()

                HStack(spacing: 8) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(ttcRed)
                        .frame(width: 18, height: 18)
                        .background(ttcRed.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 5))

                    Text("Last successful update")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer(minLength: 8)

                    Text(lastUpdatedText)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    if isRefreshing {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
                .frame(minHeight: 18)
            }
            .appCardStyle(padding: 16, cornerRadius: AppDesign.cardRadius)

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
                .clipShape(RoundedRectangle(cornerRadius: AppDesign.smallRadius))
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
        VStack(alignment: .leading, spacing: 12) {
            HomeSectionHeaderView(
                title: "Saved Routes",
                systemImage: "list.bullet",
                tint: ttcRed,
                accessoryText: "\(savedRoutes.count)"
            )

            if savedRoutes.isEmpty {
                EmptyRoutesView(ttcRed: ttcRed)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else {
                List {
                    ForEach(savedRoutes) { route in
                        NavigationLink {
                            RouteDetailView(route: route, severity: routeSeverity(for: route), alerts: matchingAlerts(for: route), lastUpdatedText: lastUpdatedText, ttcRed: ttcRed, appBackground: appBackground)
                        } label: {
                            RouteCardView(
                                route: route,
                                severity: routeSeverity(for: route),
                                arrivalState: routeArrivalState(for: route)
                            )
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
                .transition(.opacity)

                Text("Swipe left to edit or remove routes")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .transition(.opacity)
            }
        }
        .animation(AppDesign.subtleAnimation, value: savedRoutes.map(\.id))
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
        filteredSuggestedRoutesCache = RouteSuggestion.filteredSuggestions(
            from: routeSuggestions,
            matching: routeNumberInput,
            selectedRouteType: selectedRouteType,
            excludingSavedRoutes: savedRoutes
        )
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

        withAnimation(AppDesign.subtleAnimation) {
            savedRoutes.append(newRoute)
        }
        saveRoutes()
        rebuildRouteAlertCache()
        refreshSavedRouteArrivalsIfPossible(force: true)
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

        withAnimation(AppDesign.subtleAnimation) {
            savedRoutes[routeIndex] = editedRoute
        }
        saveRoutes()
        rebuildRouteAlertCache()
        refreshSavedRouteArrivalsIfPossible(force: true)
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
        withAnimation(AppDesign.subtleAnimation) {
            savedRoutes.remove(atOffsets: offsets)
        }
        saveRoutes()
        rebuildRouteAlertCache()
        updateFilteredSuggestedRoutes()
        refreshSavedRouteArrivalsIfPossible(force: true)

        if let editingRouteID, deletedRouteIDs.contains(editingRouteID) {
            clearRouteForm()
        }
    }

    func deleteRoute(_ route: TTCAlertRoute) {
        withAnimation(AppDesign.subtleAnimation) {
            savedRoutes.removeAll { savedRoute in
                savedRoute.id == route.id
            }
        }
        saveRoutes()
        rebuildRouteAlertCache()
        updateFilteredSuggestedRoutes()
        refreshSavedRouteArrivalsIfPossible(force: true)

        if editingRouteID == route.id {
            clearRouteForm()
        }
    }

    func refreshAlerts(shouldSendNotifications: Bool = true) async {
        guard !isRefreshing else {
            return
        }

        withAnimation(AppDesign.subtleAnimation) {
            isRefreshing = true
            refreshErrorMessage = nil
        }

        do {
            ttcAlerts = try await TTCAlertsService().fetchAlertsFeed()
            lastUpdatedDate = Date()
            rebuildRouteAlertCache()
            saveCachedAlerts()
            saveLastUpdatedDate()

            await processAlertNotificationsAfterRefresh(shouldSendNotifications: shouldSendNotifications)
        } catch {
            withAnimation(AppDesign.subtleAnimation) {
                refreshErrorMessage = cachedAlertsMessage
            }
            print("Could not refresh TTC alerts: \(error.localizedDescription)")
        }

        withAnimation(AppDesign.subtleAnimation) {
            isRefreshing = false
        }
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

    func processAlertNotificationsAfterRefresh(shouldSendNotifications: Bool) async {
        for route in savedRoutes {
            let alerts = matchingAlerts(for: route)
            let newNotifications = RouteAlertNotificationManager.newAlertNotifications(
                for: route,
                matchingAlerts: alerts
            )

            guard shouldSendNotifications, notificationsEnabled else {
                continue
            }

            for notification in newNotifications {
                await RouteAlertNotificationManager.scheduleRouteAlertNotification(notification)
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

    func routeArrivalState(for route: TTCAlertRoute) -> SavedRouteArrivalState? {
        guard supportsSavedRouteLiveArrival(route) else {
            return nil
        }

        if let routeArrivalState = routeArrivalStates[route.id] {
            return routeArrivalState
        }

        return locationManager.isAuthorized ? .loading : .unavailable
    }

    func requestSavedRouteLocationIfNeeded() {
        guard selectedMainScreen == .alerts,
              locationManager.isAuthorized else {
            return
        }

        locationManager.requestCurrentLocation()
    }

    func refreshSavedRouteArrivalsIfPossible(force: Bool = false) {
        let eligibleRoutes = savedRoutes.filter(supportsSavedRouteLiveArrival)
        let eligibleRouteIDs = Set(eligibleRoutes.map(\.id))

        routeArrivalStates = routeArrivalStates.filter { routeID, _ in
            eligibleRouteIDs.contains(routeID)
        }
        routeArrivalCache = routeArrivalCache.filter { routeID, _ in
            eligibleRouteIDs.contains(routeID)
        }

        guard !eligibleRoutes.isEmpty else {
            routeArrivalTask?.cancel()
            return
        }

        guard selectedMainScreen == .alerts,
              let currentLocation = locationManager.currentLocation else {
            if !locationManager.isAuthorized {
                for route in eligibleRoutes {
                    routeArrivalStates[route.id] = .unavailable
                }
            }
            return
        }

        let now = Date()
        var routesToLoad: [TTCAlertRoute] = []

        for route in eligibleRoutes {
            if !force,
               let cachedArrival = routeArrivalCache[route.id],
               now.timeIntervalSince(cachedArrival.updatedAt) < routeArrivalCacheDuration {
                routeArrivalStates[route.id] = cachedArrival.state
            } else {
                routeArrivalStates[route.id] = .loading
                routesToLoad.append(route)
            }
        }

        guard !routesToLoad.isEmpty else {
            return
        }

        routeArrivalTask?.cancel()

        let stops = TTCStopsStore.bundledStops
        let arrivalService = savedRouteArrivalService

        routeArrivalTask = Task {
            for route in routesToLoad {
                if Task.isCancelled {
                    return
                }

                let arrivalState = await arrivalService.nextArrivalState(
                    for: route,
                    currentLocation: currentLocation,
                    stops: stops,
                    now: now
                )

                if Task.isCancelled {
                    return
                }

                await MainActor.run {
                    routeArrivalStates[route.id] = arrivalState
                    routeArrivalCache[route.id] = SavedRouteArrivalCacheEntry(
                        state: arrivalState,
                        updatedAt: Date()
                    )
                }
            }
        }
    }

    func supportsSavedRouteLiveArrival(_ route: TTCAlertRoute) -> Bool {
        route.routeType == .bus || route.routeType == .streetcar
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
        VStack(alignment: .center, spacing: 12) {
            RoundedRectangle(cornerRadius: AppDesign.iconRadius)
                .fill(ttcRed.opacity(0.09))
                .frame(width: 48, height: 48)
                .overlay {
                    Image(systemName: "plus.viewfinder")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(ttcRed)
                }

            Text("No saved routes yet")
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(.primary)

            Text("Add a subway, bus, or streetcar route to start tracking alerts.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .appCardStyle(padding: 20)
    }
}

//
//  ContentView.swift
//  ttc-route-alerts
//
//  Created by Seleman Shinwarie on 2026-05-19.
//

import SwiftUI

struct TTCAlertRoute: Identifiable, Codable {
    let id: UUID
    let name: String
    let status: String

    init(id: UUID = UUID(), name: String, status: String) {
        self.id = id
        self.name = name
        self.status = status
    }
}

struct ContentView: View {
    @State private var routeInput = ""
    @State private var savedRoutes = ContentView.loadRoutes()

    static let savedRoutesKey = "savedRoutes"
    static let starterRoutes = [
        TTCAlertRoute(name: "Line 1", status: "No major issues"),
        TTCAlertRoute(name: "32 Eglinton West", status: "Delay reported")
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

            HStack(spacing: 12) {
                TextField("32 or Line 1", text: $routeInput)
                    .textInputAutocapitalization(.words)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                Button {
                    addRoute()
                } label: {
                    Text("Add")
                        .fontWeight(.semibold)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .background(ttcRed)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
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
                    RouteCard(route: route, ttcRed: ttcRed)
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
        let cleanedRoute = routeInput.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanedRoute.isEmpty else {
            return
        }

        let routeAlreadyExists = savedRoutes.contains { route in
            route.name.lowercased() == cleanedRoute.lowercased()
        }

        guard !routeAlreadyExists else {
            return
        }

        let newRoute = TTCAlertRoute(
            name: cleanedRoute,
            status: "Checking status..."
        )

        savedRoutes.append(newRoute)
        saveRoutes()
        routeInput = ""
    }

    func deleteRoutes(at offsets: IndexSet) {
        savedRoutes.remove(atOffsets: offsets)
        saveRoutes()
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
                Text(route.name)
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(.primary)

                StatusBadge(status: route.status)
            }

            Spacer()
        }
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
        if status.contains("Delay") {
            return .red
        } else if status.contains("No major") {
            return .green
        } else {
            return .secondary
        }
    }

    var backgroundColor: Color {
        if status.contains("Delay") {
            return Color.red.opacity(0.12)
        } else if status.contains("No major") {
            return Color.green.opacity(0.14)
        } else {
            return Color(.systemGray6)
        }
    }
}

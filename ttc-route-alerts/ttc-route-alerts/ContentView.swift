//
//  ContentView.swift
//  ttc-route-alerts
//
//  Created by Seleman Shinwarie on 2026-05-19.
//

import SwiftUI

struct TTCAlertRoute: Identifiable {
    let id = UUID()
    let name: String
    let status: String
}

struct ContentView: View {
    @State private var routeInput = ""
    @State private var savedRoutes: [TTCAlertRoute] = [
        TTCAlertRoute(name: "Line 1", status: "No major issues"),
        TTCAlertRoute(name: "32 Eglinton West", status: "Delay reported")
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("TTC Route Alerts")
                    .font(.largeTitle)
                    .bold()

                Text("Track only the TTC routes you care about.")
                    .foregroundColor(.gray)

                HStack {
                    TextField("Enter route, e.g. 32 or Line 1", text: $routeInput)
                        .textFieldStyle(.roundedBorder)

                    Button("Add") {
                        addRoute()
                    }
                    .buttonStyle(.borderedProminent)
                }

                List(savedRoutes) { route in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(route.name)
                            .font(.headline)

                        Text(route.status)
                            .foregroundColor(route.status.contains("Delay") ? .red : .green)
                    }
                    .padding(.vertical, 6)
                }
            }
            .padding()
            .navigationTitle("My Routes")
        }
    }

    func addRoute() {
        let cleanedRoute = routeInput.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanedRoute.isEmpty else {
            return
        }

        let newRoute = TTCAlertRoute(
            name: cleanedRoute,
            status: "Checking status..."
        )

        savedRoutes.append(newRoute)
        routeInput = ""
    }
}

#Preview {
    ContentView()
}

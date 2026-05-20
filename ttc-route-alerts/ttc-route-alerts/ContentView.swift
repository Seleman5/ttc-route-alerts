//
//  ContentView.swift
//  ttc-route-alerts
//
//  Created by Seleman Shinwarie on 2026-05-19.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("TTC Route Alerts")
                .font(.largeTitle)
                .bold()

            Text("Your personalized TTC delay tracker")
                .foregroundColor(.gray)

            Button("Add Route") {

            }
            .padding()
            .background(Color.red)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}

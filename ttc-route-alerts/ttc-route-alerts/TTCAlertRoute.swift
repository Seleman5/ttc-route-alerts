//
//  TTCAlertRoute.swift
//  ttc-route-alerts
//

import Foundation

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

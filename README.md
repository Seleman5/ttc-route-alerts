## Why I Built This

TTC provides general service alerts, but commuters usually only care about routes they actually use. TTC Route Alerts focuses on personalized route tracking by allowing users to save routes and quickly see relevant service disruptions.

## Running the App

1. Clone the repository
2. Open the project in Xcode
3. Build and run on an iPhone simulator or device


# TTC Route Alerts

TTC Route Alerts is a SwiftUI app for saving your regular TTC routes and checking live service alerts that may affect them. It stores your saved routes locally, fetches current TTC alert data, and shows route status updates in a simple, easy-to-read interface.

## Features

- Save TTC routes for quick access
- Select route types: Subway, Bus, or Streetcar
- Add optional nicknames for saved routes
- Use route suggestions and autocomplete
- Load route suggestions from the bundled TTC GTFS static `routes.txt` file
- Edit saved routes without deleting and re-adding them
- Store saved routes locally with UserDefaults
- Fetch live TTC alerts
- Decode GTFS-Realtime alert data
- Match alerts to saved routes with GTFS `route_id` support and text fallback
- Show dynamic route status updates
- Display alert severity indicators
- Manually refresh alert data
- Pull down to refresh alerts
- Request local notification permission from Settings
- Send local route alert notifications after manual refresh or pull-to-refresh
- Show relative last updated timestamps
- View route detail screens
- Use a settings screen for notifications and refresh preferences
- Save a notification preference
- Save a refresh preference setting
- Handle empty, loading, and error states

## Tests

- Unit tests for route alert matching with `RouteMatcher`
- Unit tests for alert severity classification with `AlertSeverity`
- Unit tests for route input validation, normalization, suggestion matching, and duplicate detection

## Tech Stack

- Swift
- SwiftUI
- UserDefaults
- UserNotifications
- URLSession
- SwiftProtobuf
- TTC GTFS-Realtime API
- TTC GTFS static route data

## Current Screenshots

![TTC Route Alerts home screen](Screenshots/home-screen.png)

![TTC Route Alerts route list](Screenshots/route-list.png)

![TTC Route Alerts delete route screen](Screenshots/delete-route.png)

![TTC Route Alerts alert detail screen](Screenshots/alert-detail.png)

## Future Improvements

- Background refresh based on the saved refresh preference
- Remote push notifications
- Better notification scheduling and notification history

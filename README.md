## Why I Built This

TTC provides general service alerts, but commuters usually only care about routes they actually use. TTC Route Alerts focuses on personalized route tracking by allowing users to save routes and quickly see relevant service disruptions.

## Running the App

1. Clone the repository
2. Open the project in Xcode
3. Build and run on an iPhone simulator or device

## App Icon Setup

The project includes a temporary TTC-inspired app icon in:

`ttc-route-alerts/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png`

The current Xcode asset catalog uses the newer iOS universal app icon format. Replace the placeholder with a production 1024x1024 PNG and keep it assigned in `AppIcon.appiconset/Contents.json` for the Any, Dark, and Tinted appearances. The image should be square, opaque, and should not include the official TTC logo or any other copyrighted transit mark.

For older or manually expanded icon catalogs, iOS app icons are commonly needed at these point sizes and scales:

- iPhone notification/settings/spotlight sizes: 20, 29, 40, and 60 pt at @2x/@3x
- iPad notification/settings/spotlight/app sizes: 20, 29, 40, 76, and 83.5 pt at the required iPad scales
- App Store marketing icon: 1024x1024 px

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
- Automatically refresh alerts while the app is open
- Use iOS BackgroundTasks for best-effort background TTC alert refresh
- Cache the last successful alerts for offline or network failure cases
- Request local notification permission from Settings
- Send local route alert notifications after manual refresh or pull-to-refresh
- Send background local notifications for saved routes with alerts when background refresh runs
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
- BackgroundTasks
- SwiftProtobuf
- TTC GTFS-Realtime API
- TTC GTFS static route data

## Important Notes

- iOS controls the exact timing of background refresh.
- The 5 minute and 15 minute refresh preferences are earliest refresh hints only.
- Background refresh is best-effort and depends on iOS scheduling, battery, network availability, and usage patterns.
- Remote push notifications are not implemented.

## Current Screenshots

![TTC Route Alerts home screen](Screenshots/home-screen.png)

![TTC Route Alerts route list](Screenshots/route-list.png)

![TTC Route Alerts delete route screen](Screenshots/delete-route.png)

![TTC Route Alerts alert detail screen](Screenshots/alert-detail.png)

## Future Improvements

- Smarter notification deduplication across launches
- More advanced background scheduling
- Remote push notifications
- Better offline persistence and alert history

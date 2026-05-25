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
- Edit saved routes without deleting and re-adding them
- Store saved routes locally with UserDefaults
- Fetch live TTC alerts
- Decode GTFS-Realtime alert data
- Match alerts to saved routes
- Show dynamic route status updates
- Display alert severity indicators
- Manually refresh alert data
- Pull down to refresh alerts
- Show relative last updated timestamps
- View route detail screens
- Use a settings screen for future app controls
- Save a future-ready notification preference
- Save a refresh preference setting
- Handle empty, loading, and error states

## Tech Stack

- Swift
- SwiftUI
- UserDefaults
- URLSession
- SwiftProtobuf
- TTC GTFS-Realtime API

## Current Screenshots

![TTC Route Alerts home screen](Screenshots/home-screen.png)

![TTC Route Alerts route list](Screenshots/route-list.png)

![TTC Route Alerts delete route screen](Screenshots/delete-route.png)

![TTC Route Alerts alert detail screen](Screenshots/alert-detail.png)

## Future Improvements

- Real push notifications
- Automatic refresh based on saved refresh preference
- Full TTC GTFS route database integration
- Better route matching with official route IDs

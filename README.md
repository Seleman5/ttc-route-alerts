# TTC Route Alerts

TTC Route Alerts is a SwiftUI app for saving your regular TTC routes and checking live service alerts that may affect them. It stores your saved routes locally, fetches current TTC alert data, and shows route status updates in a simple, easy-to-read interface.

## Features

- Save TTC routes for quick access
- Select route types: Subway, Bus, or Streetcar
- Add optional nicknames for saved routes
- Store saved routes locally with UserDefaults
- Fetch live TTC alerts
- Decode GTFS-Realtime alert data
- Match alerts to saved routes
- Show dynamic route status updates
- Display alert severity indicators
- Manually refresh alert data
- Show the last updated timestamp
- View route detail screens
- Handle empty, loading, and error states

## Tech Stack

- Swift
- SwiftUI
- UserDefaults
- URLSession
- SwiftProtobuf
- TTC GTFS-Realtime API

## Current Screenshots

![TTC Route Alerts home screen](Screenshots/Simulator%20Screenshot%20-%20iPhone%2017%20Pro%20-%202026-05-25%20at%2012.07.35.png)

![TTC Route Alerts route list](Screenshots/Simulator%20Screenshot%20-%20iPhone%2017%20Pro%20-%202026-05-25%20at%2012.09.50.png)

![TTC Route Alerts route details](Screenshots/Simulator%20Screenshot%20-%20iPhone%2017%20Pro%20-%202026-05-25%20at%2012.10.04.png)

![TTC Route Alerts alert details](Screenshots/Simulator%20Screenshot%20-%20iPhone%2017%20Pro%20-%202026-05-25%20at%2012.10.41.png)

## Future Improvements

- Push notifications
- Background refresh
- Better route matching
- Route suggestions

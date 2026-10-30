# Frontend Status

Last updated: 30 October 2026.

“Built” means the feature exists in the source code. See [verification-status.md](verification-status.md) for what has been tested and by whom.

## Mobile app (Flutter)

| Area | Passenger | Driver |
| --- | --- | --- |
| Sign in (email + password; role from account) | Built | Built |
| Browse / search trips (direction, route, time) | Built | – |
| Trip details and route stops on a map | Built | Built |
| I’m Taking This Trip / cancel; drop-off stop (list or map) | Built | – |
| Live bus tracking | Built | – |
| Assigned trips, start / end, delay, GPS sharing | – | Built |
| Passengers joined / Expected Riders, Bus Nearly Full | – | Built |
| Your Trips (trips with an active intent) | Built (no history) | – |
| Notifications inbox (in-app) | Built | Built |
| Reports with photo/video attachments and replies | Built | Built |
| Account page, Arabic / RTL | Not built | Not built |

## Admin dashboard (React)

| Area | Status |
| --- | --- |
| Admin sign-in | Built |
| Live Operations map with Expected Riders and capacity, Call Driver | Built |
| Trips: create, edit, cancel with reason, restore, delete, joined passengers | Built |
| Routes and Stops management | Built |
| Fleet: buses and drivers | Built |
| Reports inbox: status and response | Built |
| Notification bell | Built |
| Source map of the 86 collected University City points | Built |

## Known gaps

- No push notifications, trip history, emergency alerts, or chat.
- The mobile session is not persisted; the user signs in again after the app restarts.
- The university logo asset has not been added.

# Gravitones — HLS Video Streaming App

A small SwiftUI app that logs in against the HLS Interview Platform API, lists the
available videos, and plays them back with AVPlayer (adaptive bitrate over HLS).

## Requirements

- Xcode 16 or newer
- iOS 18.0+ (simulator or device)

## Setup

The base URL is not committed to the repo, so you need to add it once before the
project will build:

1. Copy the secrets template:

   ```
   cp "GravitonesAssignment/Configuration/Secrets.swift.example" \
      "GravitonesAssignment/Configuration/Secrets.swift"
   ```

2. Open `Secrets.swift` and set the base URL:

   ```swift
   enum Secrets {
       static let apiBaseURL = "http://<base-url>"   // no trailing slash
   }
   ```

   `Secrets.swift` is gitignored, so it stays out of source control.

3. Open `GravitonesAssignment.xcodeproj`, pick an iOS 18 simulator, and run.

To run on a real device, select your team under Signing & Capabilities first.

> The API is served over plain HTTP, so there's an App Transport Security
> exception in `Info.plist`. The CDN video URLs are HTTPS and aren't affected.

## What's implemented

- **Login** — email/password, tokens stored in the Keychain (not UserDefaults).
- **Session handling** — the session is restored from the Keychain on launch, so
  you stay logged in. An expired access token is refreshed silently on a 401 and
  the request is retried; if the refresh token is also dead the user is sent back
  to login. Logout clears the session server-side and locally.
- **Video list** — paginated list with loading / empty / error states, pull to
  refresh, and infinite scroll.
- **Player** — plays the HLS master playlist through AVPlayerViewController, which
  handles rendition switching. The player sizes itself to the video's real aspect
  ratio (portrait or landscape). Buffering and playback errors are surfaced from
  AVFoundation observers, with a retry option.
- **Video states** — READY plays; PROCESSING and FAILED show a proper state
  instead of a blank/broken player.

## How it's put together

Fairly standard MVVM:

- `GlobalFunctions/` — Keychain helpers, the networking layer (`APIClient`,
  `HeaderManager`, `serviceUrl`), the videos service, and the thumbnail loader.
- `Model/` — Codable models for auth and videos.
- `ViewModel/` — `AuthViewModel`, `VideoListViewModel`, `VideoPlayerViewModel`.
- `Screens/` — the SwiftUI views.

`APIClient` is the single point every request goes through, which is where the
refresh-on-401 lives, so the video calls get it for free. Concurrent 401s only
trigger one refresh (single-flighted through an actor).

## Assumptions

- Only the base URL is treated as a secret; credentials are entered at runtime,
  never stored in code.
- The API doesn't return a thumbnail/poster for a video, so list thumbnails are
  generated from the stream itself with `AVAssetImageGenerator` (cached).
- At the time of building, the account had 5 videos, all READY. PROCESSING and
  FAILED are handled defensively per the spec but couldn't be exercised against
  live data.

## What I'd improve with more time

- Refresh the access token proactively (shortly before it expires) instead of
  only reacting to a 401.
- Cache generated thumbnails on disk and cancel generation for rows scrolled off.
- Poll a PROCESSING video until it becomes READY.
- Add unit tests for the view models and networking with a mocked `APIClient`.
- Pull the hardcoded strings into a localizable catalog.

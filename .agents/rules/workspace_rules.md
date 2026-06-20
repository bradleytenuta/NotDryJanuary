# Workspace Rules for NotDryJanuary

## Environment
- Flutter SDK version: 3.41.1 (stable)
- Dart version: 3.11.0
- Java version: OpenJDK 1.8.0_472 (Amazon Corretto 8)

## Device And Testing Preferences
- Prioritize mobile-first development and testing.
- Preferred test device: Google Pixel 7a.
- When running locally, prefer the Pixel 7a target over emulator/web unless explicitly requested otherwise.
- Keep instructions and fixes compatible with Android testing workflows.
- Note that Mapbox maps and ModelViewer elements require native dependencies; therefore, unit/widget tests must mock geolocation (`FakeGeolocatorPlatform`), files/paths (`MockPathProviderPlatform`), and Mapbox controllers (`MockMapboxMapController`) to avoid native errors.

## Product Context
This app is a Pokemon Go style location-based mobile application built with Flutter and Mapbox Maps (not Google Maps).

Core experience:
- Show the player character on a live Mapbox map in a third-person perspective style.
- The player character is a 3D avatar rendered via `model_viewer_plus` (e.g., `assets/models/adventurer.glb`).
- Render pubs as map markers loaded from `assets/geojson/london-pubs.geojson`.
- As the user gets closer to pubs, reveal nearby pub interactions and context.
- Uses Lottie animations (e.g., `assets/lottie/liquid-fill.json`) for engaging transitions/actions.

## Coding Guidance For This Repository
- Favor practical, incremental changes that preserve current behavior.
- Keep map and geolocation logic clear and robust for real-device movement.
- Prefer solutions that are performant on mid-range Android phones (including Pixel 7a).
- Add or update tests where behavior changes, with emphasis on map state updates and proximity logic.
- When starting/running the app, verify that `--dart-define=MAPS_API_KEY=<token>` is supplied, as Mapbox will fail to load without an access token.

## Prompt Handling Preferences
- Use this document as the default context for all future prompts in this repository.
- If a prompt is ambiguous, assume the request targets the mobile Mapbox gameplay experience described above.

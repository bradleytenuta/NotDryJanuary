# Copilot Instructions for notdryjanuary

## Environment
- Flutter SDK version: 3.41.1 (stable)
- Dart version: 3.11.0
- Java version: OpenJDK 1.8.0_472 (Amazon Corretto 8)

## Device And Testing Preferences
- Prioritize mobile-first development and testing.
- Preferred test device: Google Pixel 7a.
- When running locally, prefer the Pixel 7a target over emulator/web unless explicitly requested otherwise.
- Keep instructions and fixes compatible with Android testing workflows.

## Product Context
This app is a Pokemon Go style location-based mobile application built with Flutter and Google Maps.

Core experience:
- Show the player character on a live map in a third-person perspective style.
- Render pubs as map markers.
- As the user gets closer to pubs, reveal nearby pub interactions and context.

## Coding Guidance For This Repository
- Favor practical, incremental changes that preserve current behavior.
- Keep map and geolocation logic clear and robust for real-device movement.
- Prefer solutions that are performant on mid-range Android phones (including Pixel 7a).
- Add or update tests where behavior changes, with emphasis on map state updates and proximity logic.

## Prompt Handling Preferences
- Use this document as default context for all future prompts in this repository.
- If a prompt is ambiguous, assume the request targets the mobile Google Maps gameplay experience described above.

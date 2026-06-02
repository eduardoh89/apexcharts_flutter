# apex_dart example gallery

A small Flutter app that renders every `apex_dart` chart type so the port can
be eyeballed on macOS / web / Android / Windows. Hover any chart for tooltips.

## Run

The Inter font used by the gallery is **not committed here** (it lives once in
`../test/assets/fonts/`). Copy it in first:

```bash
mkdir -p fonts
cp ../test/assets/fonts/Inter-Variable.ttf fonts/

flutter pub get
flutter run -d chrome          # or -d macos / -d windows
# or build a static bundle:
flutter build web --release
```

This implements Maria Thun's biodynamic planting calendar algorithm, in Dart and a Flutter app that shows you whether a day is good for planting root crops, leaf crops, flower crops, or fruit crops.

## Development

```sh
flutter pub get
flutter run          # or: flutter run -d linux
flutter test
flutter analyze
```

### The native Swiss Ephemeris library

Astronomical positions come from [`sweph`](https://pub.dev/packages/sweph), a
Flutter plugin wrapping the Swiss Ephemeris C library. The plugin's native
library is produced by the *platform* build, which plain `flutter test` does not
run — so tests that need real ephemeris data have to find `libsweph.so`
themselves.

[`test/support/sweph_test_loader.dart`](test/support/sweph_test_loader.dart)
handles this: it locates the library and preloads it before `Sweph.init()`. Any
test needing ephemeris data should call it first:

```dart
setUpAll(() async {
  await ensureSwephLoaded();
  await Sweph.init();
});
```

It searches, in order:

1. `$SWEPH_LIBRARY_PATH`, if set
2. the package root
3. `build/<platform>/.../` from a local desktop build
4. the prebuilt copy inside the resolved `sweph` package

If none exist, run `flutter build linux` once to produce it. The loader raises an
error listing every path it tried, so a missing library is diagnosable rather
than a bare `Failed to load dynamic library`.

### Repository layout

| Path | Contents |
| --- | --- |
| `lib/src/core/` | Domain logic: the Thun algorithm, constellation boundaries, preparations, crop data |
| `lib/src/services/` | Ephemeris and weather services |
| `lib/src/repository/` | HTTP clients for upstream weather APIs |
| `lib/src/ui/` | Widgets, custom painters, and theme |
| `test/support/` | Shared test helpers |
| `packages/` | Git-ignored vendored reference copies; **not** part of the build (`sweph` resolves from pub.dev) |
| `thun26/` | Reference photographs of the printed 2026 Thun calendar |
</CodeContent>
<parameter name="Description">Documents build/test/analyze commands and the native Swiss Ephemeris library requirement that previously made 38% of the test suite silently unrunnable.</parameter>
<parameter name="Overwrite">true

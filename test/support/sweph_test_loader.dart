// Test-only helper for loading the native Swiss Ephemeris library.
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

/// Locates and preloads the native Swiss Ephemeris shared library.
///
/// The `sweph` package is a Flutter *plugin*: its native library is built and
/// bundled by the platform build (CMake on Linux, Gradle on Android, ...).
/// Plain `flutter test` runs on the Dart VM without that platform build step,
/// so nothing places the library where the dynamic loader can find it, and
/// `Sweph.init()` fails with:
///
/// ```text
/// Invalid argument(s): Failed to load dynamic library 'libsweph.so'
/// ```
///
/// This helper works around that by loading the library from an *absolute*
/// path. Because the library declares a `SONAME` (`libsweph.so`), the loader
/// registers it under that name, so the bare `DynamicLibrary.open('libsweph.so')`
/// performed inside `Sweph.init()` then resolves to the already-loaded object
/// instead of searching the filesystem.
///
/// Call this before `Sweph.init()` in any test that needs real ephemeris data:
///
/// ```dart
/// setUpAll(() async {
///   await ensureSwephLoaded();
///   await Sweph.init();
/// });
/// ```
///
/// Calling it more than once is harmless. Throws a [StateError] listing every
/// location searched if the library cannot be found.
Future<void> ensureSwephLoaded() async {
  if (_loaded) {
    return;
  }

  final candidates = await _candidatePaths();
  for (final path in candidates) {
    if (File(path).existsSync()) {
      DynamicLibrary.open(path);
      _loaded = true;
      return;
    }
  }

  throw StateError(
    'Could not find the native Swiss Ephemeris library ($_libraryName).\n'
    '\n'
    'Searched:\n'
    '${candidates.map((p) => '  - $p').join('\n')}\n'
    '\n'
    'Build it once with `flutter build linux` (or the equivalent for your\n'
    'platform), or point $_envVar at the library explicitly.',
  );
}

bool _loaded = false;

/// Environment variable used to override library discovery.
const String _envVar = 'SWEPH_LIBRARY_PATH';

/// Platform-specific name of the Swiss Ephemeris shared library.
String get _libraryName {
  if (Platform.isWindows) {
    return 'sweph.dll';
  }
  if (Platform.isMacOS) {
    return 'libsweph.dylib';
  }
  return 'libsweph.so';
}

/// Absolute paths to try, in priority order.
Future<List<String>> _candidatePaths() async {
  final name = _libraryName;
  final paths = <String>[];

  // 1. Explicit override always wins.
  final override = Platform.environment[_envVar];
  if (override != null && override.isNotEmpty) {
    paths.add(override);
  }

  // 2. A copy kept at the package root (how this repo has historically worked).
  paths.add(_absolute(name));

  // 3. Output of a local desktop build.
  for (final mode in const ['debug', 'release', 'profile']) {
    paths
      ..add(_absolute('build/linux/x64/$mode/bundle/lib/$name'))
      ..add(_absolute('build/macos/Build/Products/$mode/$name'));
  }

  // 4. The prebuilt copy shipped inside the resolved `sweph` package itself.
  final packageBuildDir = await _swephPackageBuildDir();
  if (packageBuildDir != null) {
    paths.add('$packageBuildDir/$name');
  }

  return paths;
}

String _absolute(String relative) =>
    '${Directory.current.path}${Platform.pathSeparator}$relative';

/// Resolves the `build/` directory inside the resolved `sweph` package, or
/// `null` if the package cannot be located.
Future<String?> _swephPackageBuildDir() async {
  try {
    final uri = await Isolate.resolvePackageUri(
      Uri.parse('package:sweph/sweph.dart'),
    );
    if (uri == null) {
      return null;
    }
    // .../sweph-<version>/lib/sweph.dart -> .../sweph-<version>/build
    return '${File.fromUri(uri).parent.parent.path}/build';
  } on Object {
    // Package resolution is best-effort; fall through to the other candidates.
    return null;
  }
}

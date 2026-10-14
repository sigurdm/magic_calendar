import 'climate_service.dart';

/// Creates a persistent [ClimateProfileStore] at [directoryPath], or returns
/// null on platforms without a local file system.
ClimateProfileStore? createFileClimateProfileStore(String directoryPath) =>
    null;

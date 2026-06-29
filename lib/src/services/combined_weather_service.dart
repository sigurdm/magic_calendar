import 'weather_service.dart';

/// A weather service combining Yr.no for forecasts and DMI for historical data in Denmark.
final class CombinedWeatherService implements WeatherService {
  /// Weather service for Yr.no forecasts.
  final WeatherService yrNoService;

  /// Weather service for DMI historical data.
  final WeatherService dmiService;

  /// Creates a [CombinedWeatherService].
  CombinedWeatherService({required this.yrNoService, required this.dmiService});

  @override
  Future<List<WeatherDataPoint>> getForecast(double lat, double lon) {
    return yrNoService.getForecast(lat, lon);
  }

  @override
  Future<List<WeatherDataPoint>> getHistoricalData(
    double lat,
    double lon,
    DateTime start,
    DateTime end,
  ) async {
    if (lat >= 54.5 && lat <= 57.8 && lon >= 8.0 && lon <= 12.7) {
      try {
        return await dmiService.getHistoricalData(lat, lon, start, end);
      } catch (e) {
        return await yrNoService.getHistoricalData(lat, lon, start, end);
      }
    } else {
      return await yrNoService.getHistoricalData(lat, lon, start, end);
    }
  }
}

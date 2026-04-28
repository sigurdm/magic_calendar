import 'weather_service.dart';

/// A weather service that combines Yr.no for forecasts and DMI for historical data in Denmark.
final class CombinedWeatherService implements WeatherService {
  final YrNoWeatherService yrNoService;
  final DmiWeatherService dmiService;

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
  ) {
    // Check if location is in Denmark
    // Denmark is roughly between 54.5 and 57.8 latitude, and 8.0 and 12.7 longitude.
    if (lat >= 54.5 && lat <= 57.8 && lon >= 8.0 && lon <= 12.7) {
      try {
        return dmiService.getHistoricalData(lat, lon, start, end);
      } catch (e) {
        // Fallback to Frost (implemented in YrNoWeatherService) if DMI fails
        return yrNoService.getHistoricalData(lat, lon, start, end);
      }
    } else {
      return yrNoService.getHistoricalData(lat, lon, start, end);
    }
  }
}

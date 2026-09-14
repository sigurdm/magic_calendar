import '../repository/open_meteo_client.dart';
import 'weather_service.dart';

/// A weather service fetching data via OpenMeteo repository client for DMI coverage.
final class DmiWeatherService implements WeatherService {
  final OpenMeteoClient _openMeteoClient;

  /// Creates a [DmiWeatherService].
  ///
  /// Optionally accepts a custom [openMeteoClient] for testing.
  DmiWeatherService({OpenMeteoClient? openMeteoClient})
    : _openMeteoClient = openMeteoClient ?? OpenMeteoClient();

  @override
  Future<List<WeatherDataPoint>> getForecast(double lat, double lon) async {
    throw UnimplementedError(
      'getForecast not implemented in DmiWeatherService. Use YrNoWeatherService for forecasts.',
    );
  }

  @override
  Future<List<WeatherDataPoint>> getHistoricalData(
    double lat,
    double lon,
    DateTime start,
    DateTime end,
  ) {
    return _openMeteoClient.getHistoricalData(lat, lon, start, end);
  }

  @override
  void close() {
    _openMeteoClient.close();
  }
}

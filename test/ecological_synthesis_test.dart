import 'package:flutter_test/flutter_test.dart';
import 'package:magic_calendar/src/core/ecological_synthesis.dart';
import 'package:magic_calendar/src/core/models/models.dart';

void main() {
  final sampleCalendarInfo = CalendarInfo(
    quality: PlantQuality.root,
    isGrayDay: false,
    message: 'Root Day',
    sapFlow: 'Descending: Sap recedes to roots',
    vitality: 'Waning Crescent',
    moonPhase: MoonPhaseInfo(
      illuminatedFraction: 0.3,
      isWaxing: false,
      phaseAngle: 240,
    ),
    planets: [],
  );

  group('EcologicalSynthesis - Real-Time Weather Synthesizer', () {
    test('Identifies waterlogging when precipitation > 2.0 mm and prevents tillage', () {
      final wetPoint = WeatherDataPoint(
        time: DateTime.utc(2026, 4, 15, 14, 0),
        temperature: 12.0,
        windSpeed: 3.0,
        windDirection: 180,
        cloudCover: 90,
        precipitation: 3.5, // > 2.0 mm!
      );

      final result = EcologicalSynthesis.synthesize(
        calendarInfo: sampleCalendarInfo,
        time: DateTime.utc(2026, 4, 15, 14, 0),
        weather: wetPoint,
      );

      expect(result.hasWaterlogging, isTrue);
      expect(result.hasConflicts, isTrue);
      expect(result.bannerTitle, EcologicalSynthesis.bannerMotto);
      expect(result.alerts.any((a) => a.preventsTillage), isTrue);
      final waterAlert = result.alerts.firstWhere(
        (a) => a.type == EcologicalAlertType.waterlogging,
      );
      expect(waterAlert.title, contains('Waterlogging'));
      expect(waterAlert.practicalAdvice, contains('compaction'));
    });

    test('No waterlogging alert when precipitation <= 2.0 mm', () {
      final mildRain = WeatherDataPoint(
        time: DateTime.utc(2026, 4, 15, 14, 0),
        temperature: 12.0,
        windSpeed: 3.0,
        windDirection: 180,
        cloudCover: 60,
        precipitation: 1.2, // <= 2.0 mm
      );

      final result = EcologicalSynthesis.synthesize(
        calendarInfo: sampleCalendarInfo,
        time: DateTime.utc(2026, 4, 15, 14, 0),
        weather: mildRain,
      );

      expect(result.hasWaterlogging, isFalse);
    });

    test('Identifies sub-zero freezing (<= 0°C) and advises indoor greenhouse sowing', () {
      final freezingPoint = WeatherDataPoint(
        time: DateTime.utc(2026, 3, 5, 8, 0),
        temperature: -1.5, // <= 0°C!
        windSpeed: 2.0,
        windDirection: 45,
        cloudCover: 10,
        precipitation: 0.0,
      );

      final result = EcologicalSynthesis.synthesize(
        calendarInfo: sampleCalendarInfo,
        time: DateTime.utc(2026, 3, 5, 8, 0),
        weather: freezingPoint,
      );

      expect(result.isFreezing, isTrue);
      expect(result.hasConflicts, isTrue);
      final freezeAlert = result.alerts.firstWhere(
        (a) => a.type == EcologicalAlertType.freezing,
      );
      expect(freezeAlert.indoorSowingAdvised, isTrue);
      expect(freezeAlert.practicalAdvice, contains('greenhouse'));
    });

    test('Identifies high wind (> 5.5 m/s) and warns against spray drift', () {
      final windyPoint = WeatherDataPoint(
        time: DateTime.utc(2026, 5, 20, 16, 0),
        temperature: 18.0,
        windSpeed: 6.8, // > 5.5 m/s!
        windDirection: 270,
        cloudCover: 30,
        precipitation: 0.0,
      );

      final result = EcologicalSynthesis.synthesize(
        calendarInfo: sampleCalendarInfo,
        time: DateTime.utc(2026, 5, 20, 16, 0),
        weather: windyPoint,
      );

      expect(result.hasHighWind, isTrue);
      expect(result.hasConflicts, isTrue);
      final windAlert = result.alerts.firstWhere(
        (a) => a.type == EcologicalAlertType.highWind,
      );
      expect(windAlert.preventsSpray, isTrue);
      expect(windAlert.title, contains('Spray Drift'));
      expect(windAlert.practicalAdvice, contains('BD 501'));
    });

    test('Advises BD 507 Valerian spray when spring frost risk (< 2°C) is detected', () {
      final frostPoint = WeatherDataPoint(
        time: DateTime.utc(2026, 4, 25, 20, 0),
        temperature: 1.2, // < 2.0°C!
        windSpeed: 1.5,
        windDirection: 90,
        cloudCover: 5,
        precipitation: 0.0,
      );

      final result = EcologicalSynthesis.synthesize(
        calendarInfo: sampleCalendarInfo,
        time: DateTime.utc(
          2026,
          4,
          25,
          20,
          0,
        ), // Month 4 (Spring in Northern Hemisphere)
        weather: frostPoint,
        latitude: 55.6761,
      );

      expect(result.hasFrostRisk, isTrue);
      final frostAlert = result.alerts.firstWhere(
        (a) => a.type == EcologicalAlertType.springFrostRisk,
      );
      expect(frostAlert.valerianSprayAdvised, isTrue);
      expect(frostAlert.practicalAdvice, contains('BD 507'));
      expect(frostAlert.practicalAdvice, contains('Valerian'));
      expect(frostAlert.title, contains('Spring Frost Risk'));
    });

    test(
      'Harmonious conditions when weather is calm and within ideal ranges',
      () {
        final idealWeather = WeatherDataPoint(
          time: DateTime.utc(2026, 6, 15, 11, 0),
          temperature: 20.0,
          windSpeed: 2.5,
          windDirection: 180,
          cloudCover: 25,
          precipitation: 0.0,
        );

        final result = EcologicalSynthesis.synthesize(
          calendarInfo: sampleCalendarInfo,
          time: DateTime.utc(2026, 6, 15, 11, 0),
          weather: idealWeather,
        );

        expect(result.hasConflicts, isFalse);
        expect(result.alerts, isEmpty);
        expect(result.bannerSubtitle, contains('harmoniously aligned'));
      },
    );

    test('Gracefully handles null weather data', () {
      final result = EcologicalSynthesis.synthesize(
        calendarInfo: sampleCalendarInfo,
        time: DateTime.utc(2026, 6, 15, 11, 0),
        weather: null,
      );

      expect(result.hasConflicts, isFalse);
      expect(result.alerts, isEmpty);
      expect(result.bannerTitle, EcologicalSynthesis.bannerMotto);
      expect(
        result.bannerSubtitle,
        contains('Awaiting terrestrial weather data'),
      );
    });

    test(
      'Does not report false freezing or frost risk when temperature is null',
      () {
        final nullTempWeather = WeatherDataPoint(
          time: DateTime.utc(2026, 4, 15, 11, 0),
          temperature: null,
          windSpeed: 2.0,
          windDirection: 180,
          cloudCover: 20,
          precipitation: 0.0,
        );

        final result = EcologicalSynthesis.synthesize(
          calendarInfo: sampleCalendarInfo,
          time: DateTime.utc(2026, 4, 15, 11, 0),
          weather: nullTempWeather,
          latitude: 55.6761,
        );

        expect(result.isFreezing, isFalse);
        expect(result.hasFrostRisk, isFalse);
        expect(result.alerts, isEmpty);
      },
    );
  });
}

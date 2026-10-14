import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/climate/climate.dart';
import '../../services/garden_service.dart';
import '../theme/goethean_palette.dart';
import '../views/element_cards_gallery_page.dart';
import '../views/help_screen.dart';
import 'climate_details_sheet.dart';
import 'location_picker_dialog.dart';
import 'organic_vessel_container.dart';

/// Top header bar displaying location badge, app title, and action buttons.
final class HomeHeader extends StatelessWidget {
  /// Latitude notifier.
  final ValueNotifier<double> latNotifier;

  /// Longitude notifier.
  final ValueNotifier<double> lonNotifier;

  /// Selected date notifier.
  final ValueNotifier<DateTime> selectedDateNotifier;

  /// Callback to scroll timeline to current time.
  final VoidCallback onNowPressed;

  /// Callback when a specific date is selected via calendar dialog.
  final ValueChanged<DateTime> onDateSelected;

  /// Optional notifier supplying the 30-year [ClimateProfile] for the location.
  final ValueListenable<ClimateProfile?>? climateNotifier;

  /// Optional reactive controller for the user's persisted garden profile.
  final GardenProfileController? gardenController;

  /// Creates a [HomeHeader].
  const HomeHeader({
    super.key,
    required this.latNotifier,
    required this.lonNotifier,
    required this.selectedDateNotifier,
    required this.onNowPressed,
    required this.onDateSelected,
    this.climateNotifier,
    this.gardenController,
  });

  void _showLocationPicker(BuildContext context) {
    final activeLoc = gardenController?.value.activeLocation;
    final initialName =
        (activeLoc != null &&
            activeLoc.matchesCoordinates(latNotifier.value, lonNotifier.value))
        ? activeLoc.name
        : '';
    showDialog<void>(
      context: context,
      builder: (context) => LocationPickerDialog(
        initialLatitude: latNotifier.value,
        initialLongitude: lonNotifier.value,
        initialName: initialName,
        gardenController: gardenController,
        onLocationSaved: (lat, lon) {
          latNotifier.value = lat;
          lonNotifier.value = lon;
        },
        onNamedLocationSaved: (saved) {
          gardenController?.setActiveLocation(saved);
        },
      ),
    );
  }

  Widget _buildClimateBadge(BuildContext context, Color warmGold) {
    final notifier = climateNotifier;
    if (notifier == null) return const SizedBox.shrink();
    return ValueListenableBuilder<ClimateProfile?>(
      valueListenable: notifier,
      builder: (context, profile, _) {
        if (profile == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(left: 8),
          child: GestureDetector(
            key: const ValueKey('climate_zone_chip'),
            onTap: () => showClimateDetailsSheet(
              context,
              profile: profile,
              latitude: latNotifier.value,
              longitude: lonNotifier.value,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: OrganicVesselContainer.inset(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                accentColor: GoetheanPalette.leafWater,
                seed: 2.4,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.thermostat_outlined,
                      size: 16,
                      color: Color(0xFF6EE7B7),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${profile.koppen.code} · ${profile.hardinessZone.label}',
                      style: GoogleFonts.outfit(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: warmGold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    const warmGold = Color(0xFFF3E5C8);
    const iconColor = warmGold;
    const subIconColor = GoetheanPalette.aspectGold;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;

        final locationListenables = <Listenable>[
          latNotifier,
          lonNotifier,
          ?gardenController,
        ];

        final locationContent = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.location_on, size: 18, color: subIconColor),
            const SizedBox(width: 6),
            Flexible(
              child: ListenableBuilder(
                listenable: Listenable.merge(locationListenables),
                builder: (context, _) {
                  final lat = latNotifier.value;
                  final lon = lonNotifier.value;
                  final active = gardenController?.value.activeLocation;
                  final label =
                      (active != null &&
                          active.matchesCoordinates(lat, lon) &&
                          active.name.trim().isNotEmpty)
                      ? active.displayLabel
                      : '${lat.toStringAsFixed(1)}°, ${lon.toStringAsFixed(1)}°';
                  return Text(
                    label,
                    style: GoogleFonts.cormorantGaramond(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                      color: warmGold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  );
                },
              ),
            ),
          ],
        );

        final locationWidget = GestureDetector(
          key: const ValueKey('location_picker_button'),
          onTap: () => _showLocationPicker(context),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: OrganicVesselContainer.inset(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              accentColor: GoetheanPalette.aspectGold,
              seed: 1.2,
              child: locationContent,
            ),
          ),
        );
        final climateBadge = _buildClimateBadge(context, warmGold);

        final titleWidget = Text(
          'Magic Calendar',
          style: GoogleFonts.cinzel(
            fontSize: 19,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.6,
            color: warmGold,
          ),
          overflow: TextOverflow.ellipsis,
        );

        final nowButtonBg = GoetheanPalette.aspectGold.withValues(alpha: 0.16);
        final nowButtonBorder = BorderSide(
          color: GoetheanPalette.aspectGold.withValues(alpha: 0.38),
        );

        final actionButtons = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: TextButton.icon(
                onPressed: onNowPressed,
                icon: const Icon(Icons.history, color: iconColor, size: 18),
                label: Text(
                  'NOW',
                  style: GoogleFonts.cinzel(
                    color: iconColor,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                style: TextButton.styleFrom(
                  backgroundColor: nowButtonBg,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: nowButtonBorder,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              child: IconButton(
                key: const ValueKey('calendar_picker_button'),
                tooltip: 'Select Date',
                icon: const Icon(Icons.calendar_month, color: iconColor),
                onPressed: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: selectedDateNotifier.value,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (date != null) {
                    onDateSelected(date);
                  }
                },
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              child: IconButton(
                key: const ValueKey('element_gallery_button'),
                tooltip: 'Goethean Watercolor Elements Gallery',
                icon: const Icon(Icons.palette_outlined, color: iconColor),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) => ElementCardsGalleryPage(
                        onBackToApp: () => Navigator.of(context).pop(),
                      ),
                    ),
                  );
                },
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              child: IconButton(
                key: const ValueKey('help_screen_button'),
                tooltip: 'Help',
                icon: const Icon(Icons.help_outline, color: iconColor),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) => const HelpScreen(),
                    ),
                  );
                },
              ),
            ),
          ],
        );

        if (isMobile) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: titleWidget),
                  const SizedBox(width: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ConstrainedBox(
                        constraints: const BoxConstraints(
                          minWidth: 44,
                          minHeight: 44,
                        ),
                        child: IconButton(
                          key: const ValueKey('calendar_picker_button'),
                          tooltip: 'Select Date',
                          icon: const Icon(
                            Icons.calendar_month,
                            color: iconColor,
                            size: 22,
                          ),
                          onPressed: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: selectedDateNotifier.value,
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                            );
                            if (date != null) {
                              onDateSelected(date);
                            }
                          },
                        ),
                      ),
                      ConstrainedBox(
                        constraints: const BoxConstraints(
                          minWidth: 44,
                          minHeight: 44,
                        ),
                        child: IconButton(
                          key: const ValueKey('help_screen_button'),
                          tooltip: 'Help',
                          icon: const Icon(
                            Icons.help_outline,
                            color: iconColor,
                            size: 22,
                          ),
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (context) => const HelpScreen(),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: locationWidget),
                  climateBadge,
                  const SizedBox(width: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 40),
                    child: TextButton.icon(
                      onPressed: onNowPressed,
                      icon: const Icon(
                        Icons.history,
                        color: iconColor,
                        size: 16,
                      ),
                      label: Text(
                        'NOW',
                        style: GoogleFonts.cinzel(
                          color: iconColor,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                          fontSize: 12.5,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        backgroundColor: nowButtonBg,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: nowButtonBorder,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [locationWidget, climateBadge],
            ),
            Flexible(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: titleWidget,
              ),
            ),
            actionButtons,
          ],
        );
      },
    );
  }
}

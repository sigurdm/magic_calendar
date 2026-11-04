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
  static const Color _warmGold = Color(0xFFF3E5C8);
  static const Color _iconColor = _warmGold;
  static const Color _subIconColor = GoetheanPalette.aspectGold;

  static final TextStyle _climateBadgeStyle = GoogleFonts.outfit(
    fontSize: 12.5,
    fontWeight: FontWeight.w600,
    color: _warmGold,
  );
  static final TextStyle _locationLabelStyle = GoogleFonts.cormorantGaramond(
    fontSize: 14.5,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
    color: _warmGold,
  );
  static final TextStyle _titleStyle = GoogleFonts.cinzel(
    fontSize: 19,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.6,
    color: _warmGold,
  );
  static final TextStyle _nowDesktopLabelStyle = GoogleFonts.cinzel(
    color: _iconColor,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.2,
  );
  static final TextStyle _nowMobileLabelStyle = GoogleFonts.cinzel(
    color: _iconColor,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.1,
    fontSize: 12.5,
  );
  static final Color _nowButtonBg = GoetheanPalette.aspectGold.withValues(
    alpha: 0.16,
  );
  static final BorderSide _nowButtonBorder = BorderSide(
    color: GoetheanPalette.aspectGold.withValues(alpha: 0.38),
  );
  static final ButtonStyle _nowDesktopButtonStyle = TextButton.styleFrom(
    backgroundColor: _nowButtonBg,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: _nowButtonBorder,
    ),
  );
  static final ButtonStyle _nowMobileButtonStyle = TextButton.styleFrom(
    backgroundColor: _nowButtonBg,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: _nowButtonBorder,
    ),
  );

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

  Future<void> _pickDate(BuildContext context) async {
    final firstDate = DateTime(2000);
    final lastDate = DateTime(2100);
    final rawInitial = selectedDateNotifier.value;
    final initialDate = rawInitial.isBefore(firstDate)
        ? firstDate
        : (rawInitial.isAfter(lastDate) ? lastDate : rawInitial);
    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );
    if (date != null && context.mounted) {
      onDateSelected(date);
    }
  }

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

  Widget _buildClimateBadge(BuildContext context) {
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
                      style: _climateBadgeStyle,
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
    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 600;

          final locationContent = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.location_on, size: 18, color: _subIconColor),
              const SizedBox(width: 6),
              Flexible(
                child: _LocationLabelText(
                  latNotifier: latNotifier,
                  lonNotifier: lonNotifier,
                  gardenController: gardenController,
                  style: _locationLabelStyle,
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                accentColor: GoetheanPalette.aspectGold,
                seed: 1.2,
                child: locationContent,
              ),
            ),
          );
          final climateBadge = _buildClimateBadge(context);

          final titleWidget = Text(
            'Magic Calendar',
            style: _titleStyle,
            overflow: TextOverflow.ellipsis,
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
                              color: _iconColor,
                              size: 22,
                            ),
                            onPressed: () => _pickDate(context),
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
                              color: _iconColor,
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
                          color: _iconColor,
                          size: 16,
                        ),
                        label: Text('NOW', style: _nowMobileLabelStyle),
                        style: _nowMobileButtonStyle,
                      ),
                    ),
                  ],
                ),
              ],
            );
          }

          final actionButtons = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: TextButton.icon(
                  onPressed: onNowPressed,
                  icon: const Icon(Icons.history, color: _iconColor, size: 18),
                  label: Text('NOW', style: _nowDesktopLabelStyle),
                  style: _nowDesktopButtonStyle,
                ),
              ),
              const SizedBox(width: 4),
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                child: IconButton(
                  key: const ValueKey('calendar_picker_button'),
                  tooltip: 'Select Date',
                  icon: const Icon(Icons.calendar_month, color: _iconColor),
                  onPressed: () => _pickDate(context),
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                child: IconButton(
                  key: const ValueKey('element_gallery_button'),
                  tooltip: 'Goethean Watercolor Elements Gallery',
                  icon: const Icon(Icons.palette_outlined, color: _iconColor),
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
                  icon: const Icon(Icons.help_outline, color: _iconColor),
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
      ),
    );
  }
}

final class _LocationLabelText extends StatefulWidget {
  final ValueNotifier<double> latNotifier;
  final ValueNotifier<double> lonNotifier;
  final GardenProfileController? gardenController;
  final TextStyle style;

  const _LocationLabelText({
    required this.latNotifier,
    required this.lonNotifier,
    required this.gardenController,
    required this.style,
  });

  @override
  State<_LocationLabelText> createState() => _LocationLabelTextState();
}

final class _LocationLabelTextState extends State<_LocationLabelText> {
  late String _label;

  @override
  void initState() {
    super.initState();
    _label = _computeLabel();
    widget.latNotifier.addListener(_onChanged);
    widget.lonNotifier.addListener(_onChanged);
    widget.gardenController?.addListener(_onChanged);
  }

  @override
  void didUpdateWidget(covariant _LocationLabelText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.latNotifier != widget.latNotifier) {
      oldWidget.latNotifier.removeListener(_onChanged);
      widget.latNotifier.addListener(_onChanged);
    }
    if (oldWidget.lonNotifier != widget.lonNotifier) {
      oldWidget.lonNotifier.removeListener(_onChanged);
      widget.lonNotifier.addListener(_onChanged);
    }
    if (oldWidget.gardenController != widget.gardenController) {
      oldWidget.gardenController?.removeListener(_onChanged);
      widget.gardenController?.addListener(_onChanged);
    }
    _label = _computeLabel();
  }

  @override
  void dispose() {
    widget.latNotifier.removeListener(_onChanged);
    widget.lonNotifier.removeListener(_onChanged);
    widget.gardenController?.removeListener(_onChanged);
    super.dispose();
  }

  String _computeLabel() {
    final lat = widget.latNotifier.value;
    final lon = widget.lonNotifier.value;
    final active = widget.gardenController?.value.activeLocation;
    return (active != null &&
            active.matchesCoordinates(lat, lon) &&
            active.name.trim().isNotEmpty)
        ? active.displayLabel
        : '${lat.toStringAsFixed(1)}°, ${lon.toStringAsFixed(1)}°';
  }

  void _onChanged() {
    final next = _computeLabel();
    if (next != _label && mounted) {
      setState(() {
        _label = next;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Text(_label, style: widget.style, overflow: TextOverflow.ellipsis);
  }
}

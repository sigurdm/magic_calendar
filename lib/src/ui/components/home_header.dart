import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../views/element_cards_gallery_page.dart';
import '../views/help_screen.dart';
import 'location_picker_dialog.dart';

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

  /// Creates a [HomeHeader].
  const HomeHeader({
    super.key,
    required this.latNotifier,
    required this.lonNotifier,
    required this.selectedDateNotifier,
    required this.onNowPressed,
    required this.onDateSelected,
  });

  void _showLocationPicker(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => LocationPickerDialog(
        initialLatitude: latNotifier.value,
        initialLongitude: lonNotifier.value,
        onLocationSaved: (lat, lon) {
          latNotifier.value = lat;
          lonNotifier.value = lon;
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;

        final locationWidget = GestureDetector(
          onTap: () => _showLocationPicker(context),
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.location_on, size: 18, color: Colors.white70),
                const SizedBox(width: 4),
                Flexible(
                  child: ValueListenableBuilder<double>(
                    valueListenable: latNotifier,
                    builder: (context, lat, _) {
                      return ValueListenableBuilder<double>(
                        valueListenable: lonNotifier,
                        builder: (context, lon, _) {
                          return Text(
                            '${lat.toStringAsFixed(1)}°, ${lon.toStringAsFixed(1)}°',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              color: Colors.white70,
                            ),
                            overflow: TextOverflow.ellipsis,
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );

        final titleWidget = Text(
          'Magic Calendar',
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          overflow: TextOverflow.ellipsis,
        );

        final actionButtons = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: TextButton.icon(
                onPressed: onNowPressed,
                icon: const Icon(Icons.history, color: Colors.white, size: 18),
                label: Text(
                  'NOW',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: TextButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
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
                icon: const Icon(Icons.calendar_month, color: Colors.white),
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
                icon: const Icon(Icons.palette_outlined, color: Colors.white),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
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
                icon: const Icon(Icons.help_outline, color: Colors.white),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const HelpScreen()),
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
                            color: Colors.white,
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
                            color: Colors.white,
                            size: 22,
                          ),
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
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
                  const SizedBox(width: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 40),
                    child: TextButton.icon(
                      onPressed: onNowPressed,
                      icon: const Icon(
                        Icons.history,
                        color: Colors.white,
                        size: 16,
                      ),
                      label: Text(
                        'NOW',
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.1),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
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
          children: [locationWidget, titleWidget, actionButtons],
        );
      },
    );
  }
}

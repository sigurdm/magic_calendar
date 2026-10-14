import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/garden_service.dart';

/// Modal dialog for configuring geographic coordinates and managing saved garden locations.
final class LocationPickerDialog extends StatefulWidget {
  /// Initial latitude.
  final double initialLatitude;

  /// Initial longitude.
  final double initialLongitude;

  /// Initial optional location or garden name.
  final String initialName;

  /// Callback when location coordinates are saved.
  final void Function(double latitude, double longitude)? onLocationSaved;

  /// Optional callback when a named [SavedLocation] is saved.
  final ValueChanged<SavedLocation>? onNamedLocationSaved;

  /// Optional garden controller supplying user-saved locations.
  final GardenProfileController? gardenController;

  /// Creates a [LocationPickerDialog].
  const LocationPickerDialog({
    super.key,
    required this.initialLatitude,
    required this.initialLongitude,
    this.initialName = '',
    this.onLocationSaved,
    this.onNamedLocationSaved,
    this.gardenController,
  });

  @override
  State<LocationPickerDialog> createState() => _LocationPickerDialogState();
}

final class _LocationPickerDialogState extends State<LocationPickerDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _latController;
  late final TextEditingController _lonController;

  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final initialSaved = SavedLocation.validated(
      latitude: widget.initialLatitude.clamp(-90.0, 90.0),
      longitude: widget.initialLongitude.clamp(-180.0, 180.0),
      name: widget.initialName,
    );
    _nameController = TextEditingController(text: initialSaved.name);
    _latController = TextEditingController(
      text: widget.initialLatitude.toString(),
    );
    _lonController = TextEditingController(
      text: widget.initialLongitude.toString(),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _latController.dispose();
    _lonController.dispose();
    super.dispose();
  }

  void _applyLocation(double lat, double lon, {String name = ''}) {
    setState(() {
      _latController.text = lat.toString();
      _lonController.text = lon.toString();
      _nameController.text = name;
      _errorMessage = null;
    });
  }

  void _save() {
    final lat = double.tryParse(_latController.text);
    final lon = double.tryParse(_lonController.text);
    if (lat == null || lon == null) {
      setState(() {
        _errorMessage =
            'Please enter valid decimal numbers for latitude and longitude.';
      });
      return;
    }
    final clampedLat = lat.clamp(-90.0, 90.0);
    final clampedLon = lon.clamp(-180.0, 180.0);
    final saved = SavedLocation.validated(
      latitude: clampedLat,
      longitude: clampedLon,
      name: _nameController.text,
    );
    widget.onLocationSaved?.call(clampedLat, clampedLon);
    widget.onNamedLocationSaved?.call(saved);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.gardenController;
    return AlertDialog(
      title: Text(
        'Set Location',
        style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              key: const ValueKey('location_name_field'),
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Garden / Place Name (optional)',
                hintText: 'e.g. Home Allotment, Svendborg',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('location_latitude_field'),
              controller: _latController,
              decoration: const InputDecoration(
                labelText: 'Latitude (-90 to 90)',
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              onChanged: (_) {
                if (_errorMessage != null) {
                  setState(() => _errorMessage = null);
                }
              },
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('location_longitude_field'),
              controller: _lonController,
              decoration: const InputDecoration(
                labelText: 'Longitude (-180 to 180)',
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              onChanged: (_) {
                if (_errorMessage != null) {
                  setState(() => _errorMessage = null);
                }
              },
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 10),
              Text(
                _errorMessage!,
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: const Color(0xFFEF4444),
                ),
              ),
            ],
            if (controller != null)
              ValueListenableBuilder<GardenProfile>(
                valueListenable: controller,
                builder: (context, profile, _) {
                  if (profile.savedLocations.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      Text(
                        'Saved Garden Locations:',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: Colors.white70,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: profile.savedLocations
                            .map(_buildSavedLocationChip)
                            .toList(growable: false),
                      ),
                    ],
                  );
                },
              ),
            const SizedBox(height: 16),
            Text(
              'Quick Presets:',
              style: GoogleFonts.outfit(
                fontSize: 12,
                color: Colors.white70,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _buildPresetChip(
                  '🇩🇰 Denmark',
                  54.9037,
                  10.6074,
                  name: 'Svendborg, Denmark',
                ),
                _buildPresetChip(
                  '🇩🇪 Germany',
                  50.1109,
                  8.6821,
                  name: 'Frankfurt, Germany',
                ),
                _buildPresetChip(
                  '🇬🇧 UK',
                  51.5074,
                  -0.1278,
                  name: 'London, UK',
                ),
                _buildPresetChip(
                  '🇺🇸 USA',
                  40.7128,
                  -74.0060,
                  name: 'New York, USA',
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: GoogleFonts.outfit()),
        ),
        ElevatedButton(
          key: const ValueKey('save_location_button'),
          onPressed: _save,
          child: Text(
            'Save',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildSavedLocationChip(SavedLocation saved) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF10B981).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFF10B981).withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            key: ValueKey('saved_location_${saved.displayLabel}'),
            onTap: () => _applyLocation(
              saved.latitude,
              saved.longitude,
              name: saved.name,
            ),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 5, 4, 5),
              child: Text(
                '${saved.displayLabel} (${saved.coordinateLabel})',
                style: GoogleFonts.outfit(fontSize: 11, color: Colors.white),
              ),
            ),
          ),
          InkWell(
            key: ValueKey('delete_saved_location_${saved.displayLabel}'),
            onTap: () => widget.gardenController?.removeSavedLocation(saved),
            borderRadius: BorderRadius.circular(8),
            child: const Padding(
              padding: EdgeInsets.all(5),
              child: Icon(Icons.close, size: 13, color: Colors.white60),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetChip(
    String label,
    double lat,
    double lon, {
    required String name,
  }) {
    return InkWell(
      onTap: () => _applyLocation(lat, lon, name: name),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(fontSize: 11, color: Colors.white70),
        ),
      ),
    );
  }
}

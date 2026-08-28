import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Modal dialog for manually configuring geographic coordinates.
final class LocationPickerDialog extends StatefulWidget {
  /// Initial latitude.
  final double initialLatitude;

  /// Initial longitude.
  final double initialLongitude;

  /// Callback when location is saved.
  final void Function(double latitude, double longitude) onLocationSaved;

  /// Creates a [LocationPickerDialog].
  const LocationPickerDialog({
    super.key,
    required this.initialLatitude,
    required this.initialLongitude,
    required this.onLocationSaved,
  });

  @override
  State<LocationPickerDialog> createState() => _LocationPickerDialogState();
}

final class _LocationPickerDialogState extends State<LocationPickerDialog> {
  late final TextEditingController _latController;
  late final TextEditingController _lonController;

  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _latController = TextEditingController(
      text: widget.initialLatitude.toString(),
    );
    _lonController = TextEditingController(
      text: widget.initialLongitude.toString(),
    );
  }

  @override
  void dispose() {
    _latController.dispose();
    _lonController.dispose();
    super.dispose();
  }

  void _applyPreset(double lat, double lon) {
    setState(() {
      _latController.text = lat.toString();
      _lonController.text = lon.toString();
      _errorMessage = null;
    });
  }

  void _save() {
    final lat = double.tryParse(_latController.text);
    final lon = double.tryParse(_lonController.text);
    if (lat == null || lon == null) {
      setState(() {
        _errorMessage = 'Please enter valid decimal numbers for latitude and longitude.';
      });
      return;
    }
    widget.onLocationSaved(lat.clamp(-90.0, 90.0), lon.clamp(-180.0, 180.0));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
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
                _buildPresetChip('🇩🇰 Denmark', 54.9037, 10.6074),
                _buildPresetChip('🇩🇪 Germany', 50.1109, 8.6821),
                _buildPresetChip('🇬🇧 UK', 51.5074, -0.1278),
                _buildPresetChip('🇺🇸 USA', 40.7128, -74.0060),
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
          onPressed: _save,
          child: Text(
            'Save',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildPresetChip(String label, double lat, double lon) {
    return InkWell(
      onTap: () => _applyPreset(lat, lon),
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

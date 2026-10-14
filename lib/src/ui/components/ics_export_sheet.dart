import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/ics_calendar_exporter.dart';
import '../../services/ics_file_saver.dart';
import '../theme/goethean_palette.dart';
import 'organic_vessel_container.dart';

/// Modal bottom sheet displaying RFC 5545 `.ics` calendar export details,
/// pre-spray dynamization stirring reminders, and one-tap file save / clipboard
/// copy actions.
final class IcsExportSheet extends StatefulWidget {
  /// Events included in the `.ics` export.
  final List<CalendarExportEvent> events;

  /// Sheet header title.
  final String title;

  /// Optional sheet subtitle.
  final String? subtitle;

  /// Optional custom file saver callback for testing or custom storage targets.
  final Future<String?> Function({
    required String fileName,
    required String content,
  })?
  onSaveFile;

  /// Creates an immutable [IcsExportSheet].
  ///
  /// The [events] list must not be empty.
  IcsExportSheet({
    super.key,
    required List<CalendarExportEvent> events,
    this.title = 'Export Biodynamic Calendar (.ics)',
    this.subtitle,
    this.onSaveFile,
  }) : events = List.unmodifiable(events) {
    if (events.isEmpty) {
      throw ArgumentError.value(events, 'events', 'Must not be empty');
    }
  }

  /// Shows the [IcsExportSheet] modal bottom sheet for a single [event] or a
  /// list of [events].
  static Future<void> show(
    BuildContext context, {
    required List<CalendarExportEvent> events,
    String title = 'Export Biodynamic Calendar (.ics)',
    String? subtitle,
    Future<String?> Function({
      required String fileName,
      required String content,
    })?
    onSaveFile,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => IcsExportSheet(
        events: events,
        title: title,
        subtitle: subtitle,
        onSaveFile: onSaveFile,
      ),
    );
  }

  @override
  State<IcsExportSheet> createState() => _IcsExportSheetState();
}

final class _IcsExportSheetState extends State<IcsExportSheet> {
  bool _includeStirringEvent = true;
  bool _showRawIcsPreview = false;
  bool _copiedToClipboard = false;
  String? _savedFilePath;
  String? _errorMessage;

  bool get _anyEventHasStirring =>
      widget.events.any((event) => event.hasStirringWindow);

  String get _icsPayload => IcsCalendarExporter.formatCalendar(
    widget.events,
    calendarName: widget.title,
    includeStirringEvents: _includeStirringEvent,
  );

  String get _suggestedFileName {
    if (widget.events.length == 1) {
      return widget.events.first.suggestedFileName;
    }
    final firstStart = widget.events.first.start;
    final datePart = DateFormat('yyyy-MM-dd').format(firstStart);
    return 'magic-calendar-week-ahead-$datePart.ics';
  }

  Future<void> _handleCopyIcs() async {
    await Clipboard.setData(ClipboardData(text: _icsPayload));
    if (!mounted) return;
    setState(() {
      _copiedToClipboard = true;
      _errorMessage = null;
    });
  }

  Future<void> _handleSaveIcsFile() async {
    try {
      final saver = widget.onSaveFile ?? saveIcsFile;
      final path = await saver(
        fileName: _suggestedFileName,
        content: _icsPayload,
      );
      if (!mounted) return;
      setState(() {
        _savedFilePath = path ?? _suggestedFileName;
        _errorMessage = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Could not save .ics file: $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('EEE, MMM d • HH:mm');
    final timeFormat = DateFormat('HH:mm');
    const accentColor = GoetheanPalette.aspectGold;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 24, 12, 12),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 680,
            maxHeight: MediaQuery.of(context).size.height * 0.86,
          ),
          child: OrganicVesselContainer(
            accentColor: accentColor,
            seed: 5.2,
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.event_available_outlined,
                          color: accentColor,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.title,
                              style: GoogleFonts.cormorantGaramond(
                                fontSize: 21,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFFF6ECD8),
                              ),
                            ),
                            Text(
                              widget.subtitle ?? 'RFC 5545 iCalendar (.ics) compatible with Google, Apple & Outlook Calendars',
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        key: const ValueKey('ics_export_close_button'),
                        tooltip: 'Close',
                        icon: const Icon(Icons.close, color: Colors.white70),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  if (_anyEventHasStirring) ...[
                    SwitchListTile.adaptive(
                      key: const ValueKey('ics_include_stirring_toggle'),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 2,
                      ),
                      dense: true,
                      activeThumbColor: accentColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: accentColor.withValues(alpha: 0.35),
                        ),
                      ),
                      tileColor: accentColor.withValues(alpha: 0.08),
                      title: Text(
                        'Include Pre-Spray Stirring Event & Reminder',
                        style: GoogleFonts.outfit(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFF6ECD8),
                        ),
                      ),
                      subtitle: Text(
                        'Adds a dedicated dynamization VEVENT (e.g. 1 hour before BD 500/501 spray) plus VALARM alert',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          color: Colors.white70,
                        ),
                      ),
                      value: _includeStirringEvent,
                      onChanged: (value) {
                        setState(() {
                          _includeStirringEvent = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Event Summary Cards
                  for (final event in widget.events) ...[
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.14),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            event.summary,
                            style: GoogleFonts.outfit(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.schedule,
                                size: 14,
                                color: accentColor,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  '${dateFormat.format(event.start)} → ${timeFormat.format(event.end)}',
                                  style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFFF6ECD8),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (event.hasStirringWindow &&
                              _includeStirringEvent) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981)
                                    .withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(0xFF10B981)
                                      .withValues(alpha: 0.4),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.cyclone_outlined,
                                    size: 15,
                                    color: Color(0xFF34D399),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Stirring Start (${event.stirringDuration!.inMinutes} min): '
                                      '${dateFormat.format(event.stirringStart!)} → ${timeFormat.format(event.stirringEnd!)}',
                                      key: ValueKey(
                                        'ics_stirring_banner_${event.uid}',
                                      ),
                                      style: GoogleFonts.outfit(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFFA7F3D0),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 6),
                          Text(
                            event.description,
                            maxLines: 5,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              fontSize: 11.5,
                              color: Colors.white70,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  if (_savedFilePath != null) ...[
                    Container(
                      key: const ValueKey('ics_saved_path_banner'),
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFF10B981).withValues(alpha: 0.5),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.check_circle_outline,
                            size: 16,
                            color: Color(0xFF34D399),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Saved .ics calendar file: $_savedFilePath',
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                color: const Color(0xFFA7F3D0),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  if (_copiedToClipboard) ...[
                    Container(
                      key: const ValueKey('ics_copied_banner'),
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: accentColor.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.content_copy_outlined,
                            size: 16,
                            color: accentColor,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Copied RFC 5545 .ics calendar payload ($_suggestedFileName) to clipboard.',
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                color: const Color(0xFFF6ECD8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  if (_errorMessage != null) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        _errorMessage!,
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: const Color(0xFFF87171),
                        ),
                      ),
                    ),
                  ],

                  // Action Buttons Row
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      ElevatedButton.icon(
                        key: const ValueKey('ics_save_file_button'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentColor.withValues(alpha: 0.28),
                          foregroundColor: const Color(0xFFF6ECD8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: accentColor),
                          ),
                        ),
                        onPressed: _handleSaveIcsFile,
                        icon: const Icon(
                          Icons.download_outlined,
                          size: 18,
                          color: accentColor,
                        ),
                        label: Text(
                          'Save $_suggestedFileName',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      OutlinedButton.icon(
                        key: const ValueKey('ics_copy_clipboard_button'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.28),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _handleCopyIcs,
                        icon: const Icon(
                          Icons.copy_all_outlined,
                          size: 17,
                          color: Colors.white70,
                        ),
                        label: Text(
                          'Copy .ics Text',
                          style: GoogleFonts.outfit(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        key: const ValueKey('ics_toggle_preview_button'),
                        onPressed: () {
                          setState(() {
                            _showRawIcsPreview = !_showRawIcsPreview;
                          });
                        },
                        icon: Icon(
                          _showRawIcsPreview
                              ? Icons.visibility_off_outlined
                              : Icons.code_outlined,
                          size: 16,
                          color: Colors.white70,
                        ),
                        label: Text(
                          _showRawIcsPreview
                              ? 'Hide .ics Source'
                              : 'Preview .ics Source',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                        ),
                      ),
                    ],
                  ),

                  if (_showRawIcsPreview) ...[
                    const SizedBox(height: 12),
                    Container(
                      key: const ValueKey('ics_raw_preview_box'),
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.14),
                        ),
                      ),
                      child: SelectableText(
                        _icsPayload,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11,
                          color: const Color(0xFFE5DAC6),
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

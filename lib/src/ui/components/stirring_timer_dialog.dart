import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/biodynamic_icons.dart';

/// Preparation configuration for biodynamic dynamization stirring.
enum StirringPrepType {
  /// Horn Manure (BD 500): 60 minutes stirring, Descending Moon, late afternoon.
  bd500,

  /// Horn Silica (BD 501): 60 minutes stirring, Ascending Moon, early morning sunrise.
  bd501,

  /// Cow Pat Pit / Maria Thun Barrel Compost (CPP): 20 minutes dynamization (16 cycles of 75s).
  cpp,

  /// Horsetail decoction (BD 508): 20 minutes gentle dynamization.
  bd508,

  /// General compost tea / plant concoction (15 minutes).
  generalTea,
}

/// Interactive modal dialog providing countdown, vortex cycle tracking,
/// direction reversal alerts, Goethean dynamization guidance, and ±1 minute manual adjustments.
final class StirringTimerDialog extends StatefulWidget {
  /// Initial preparation type to configure timer for.
  final StirringPrepType initialPrep;

  /// Creates an immutable [StirringTimerDialog].
  const StirringTimerDialog({
    super.key,
    this.initialPrep = StirringPrepType.bd500,
  });

  /// Shows the dialog with backdrop blur and responsive constraints.
  static Future<void> show(
    BuildContext context, {
    StirringPrepType prep = StirringPrepType.bd500,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StirringTimerDialog(initialPrep: prep),
    );
  }

  @override
  State<StirringTimerDialog> createState() => _StirringTimerDialogState();
}

final class _StirringTimerDialogState extends State<StirringTimerDialog> {
  late StirringPrepType _selectedPrep;
  late int _totalDurationSeconds;
  int _remainingSeconds = 3600;
  bool _isRunning = false;
  bool _isComplete = false;
  Timer? _timer;

  // Vortex cycle length is 75 seconds (vortex buildup -> crater chaos -> direction reversal).
  static const int _cycleLengthSeconds = 75;

  @override
  void initState() {
    super.initState();
    _selectedPrep = widget.initialPrep;
    _setDurationForPrep(_selectedPrep);
  }

  void _setDurationForPrep(StirringPrepType prep) {
    _selectedPrep = prep;
    switch (prep) {
      case StirringPrepType.bd500:
      case StirringPrepType.bd501:
        _totalDurationSeconds = 3600; // 60 minutes
        break;
      case StirringPrepType.cpp:
      case StirringPrepType.bd508:
        _totalDurationSeconds = 1200; // 20 minutes (16 cycles of 75s)
        break;
      case StirringPrepType.generalTea:
        _totalDurationSeconds = 900; // 15 minutes
        break;
    }
    _remainingSeconds = _totalDurationSeconds;
    _isComplete = false;
  }

  void _toggleTimer() {
    if (_isRunning) {
      _timer?.cancel();
      setState(() {
        _isRunning = false;
      });
      return;
    }

    setState(() {
      // Starting again after the countdown finished rewinds it; without this
      // the tick below would drive _remainingSeconds negative.
      if (_remainingSeconds <= 0) {
        _remainingSeconds = _totalDurationSeconds;
      }
      _isComplete = false;
      _isRunning = true;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _remainingSeconds--;
      });

      if (_remainingSeconds <= 0) {
        // Finish on the tick that reaches zero. Waiting for the *next* tick to
        // notice, as this used to, made the timer run a second long.
        timer.cancel();
        setState(() {
          _isRunning = false;
          _isComplete = true;
        });
        SystemSound.play(SystemSoundType.click);
        return;
      }

      // Play audible click on 75s reversal rhythm and warning cues
      if (_secondsUntilReversal == _cycleLengthSeconds ||
          _secondsUntilReversal <= 3) {
        SystemSound.play(SystemSoundType.click);
      }
    });
  }

  void _skipSeconds(int deltaSeconds) {
    setState(() {
      _remainingSeconds = (_remainingSeconds + deltaSeconds).clamp(
        0,
        _totalDurationSeconds,
      );
    });
  }

  void _resetTimer() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
      _isComplete = false;
      _remainingSeconds = _totalDurationSeconds;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  int get _elapsedSeconds => _totalDurationSeconds - _remainingSeconds;
  int get _totalCycles => (_totalDurationSeconds / _cycleLengthSeconds).ceil();

  /// 1-based index of the cycle currently being stirred.
  ///
  /// Clamped to [_totalCycles]: when the final second elapses the raw
  /// expression lands one past the end, which read as "Cycle 49/48".
  int get _currentCycleIndex =>
      ((_elapsedSeconds ~/ _cycleLengthSeconds) + 1).clamp(1, _totalCycles);
  int get _cycleSecondsElapsed => _elapsedSeconds % _cycleLengthSeconds;
  int get _secondsUntilReversal => _cycleLengthSeconds - _cycleSecondsElapsed;

  bool get _isReversalWarning => _isRunning && _secondsUntilReversal <= 5;
  bool get _isClockwise => (_currentCycleIndex % 2) != 0;

  /// Banner shown in place of the old SnackBar once the countdown finishes.
  Widget _buildCompletionBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF10B981).withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF10B981)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Stirring complete. Apply the dynamized preparation within 1-2 hours.',
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(int totalSecs) {
    final minutes = totalSecs ~/ 60;
    final seconds = totalSecs % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String _getDropletGuidanceForPrep(StirringPrepType prep) {
    switch (prep) {
      case StirringPrepType.bd500:
      case StirringPrepType.cpp:
        return 'Coarse Soil Droplets: Apply close to soil with natural birch broom or coarse nozzle. Droplets should fall heavily like warm rain; do not aerosolize into fine mist.';
      case StirringPrepType.bd501:
        return 'Ultra-Fine Floating Mist: Atomize high into the early morning sunrise air above crop foliage, creating a drifting radiant dew.';
      case StirringPrepType.bd508:
      case StirringPrepType.generalTea:
        return 'Fine Foliar Spray: Even misty coating across foliage to establish natural fungal defense barrier without dripping runoff.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = _totalDurationSeconds > 0
        ? _elapsedSeconds / _totalDurationSeconds
        : 0.0;
    final cycleProgress = _cycleLengthSeconds > 0
        ? _cycleSecondsElapsed / _cycleLengthSeconds
        : 0.0;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 540),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E2E).withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isComplete) ...[
                    _buildCompletionBanner(),
                    const SizedBox(height: 16),
                  ],
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF646CFF)
                                  .withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const BiodynamicIcon(
                              type: BiodynamicIconType.dynamizationVortex,
                              color: Color(0xFF818CF8),
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Biodynamic Stirrer',
                                style: GoogleFonts.outfit(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                'Dynamization Vortex Timer',
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      ConstrainedBox(
                        constraints: const BoxConstraints(
                          minWidth: 48,
                          minHeight: 48,
                        ),
                        child: IconButton(
                          key: const ValueKey('close_stirring_dialog'),
                          tooltip: 'Close',
                          icon: const Icon(Icons.close, color: Colors.white70),
                          onPressed: () {
                            _timer?.cancel();
                            Navigator.of(context).pop();
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Preparation Selector Tabs
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Row(
                      children: [
                        _buildPrepTab(
                          'BD 500 (Manure)',
                          StirringPrepType.bd500,
                        ),
                        const SizedBox(width: 6),
                        _buildPrepTab(
                          'BD 501 (Silica)',
                          StirringPrepType.bd501,
                        ),
                        const SizedBox(width: 6),
                        _buildPrepTab(
                          'CPP (Barrel Compost)',
                          StirringPrepType.cpp,
                        ),
                        const SizedBox(width: 6),
                        _buildPrepTab(
                          'BD 508 (Horsetail)',
                          StirringPrepType.bd508,
                        ),
                        const SizedBox(width: 6),
                        _buildPrepTab(
                          'Concoction Tea',
                          StirringPrepType.generalTea,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Reversal Alert Banner
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: _isReversalWarning
                          ? const Color(0xFFEF4444).withValues(alpha: 0.25)
                          : (_isRunning
                                ? const Color(0xFF10B981)
                                      .withValues(alpha: 0.15)
                                : Colors.white.withValues(alpha: 0.05)),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _isReversalWarning
                            ? const Color(0xFFEF4444)
                            : (_isRunning
                                  ? const Color(0xFF10B981)
                                        .withValues(alpha: 0.4)
                                  : Colors.white.withValues(alpha: 0.1)),
                        width: _isReversalWarning ? 2.0 : 1.0,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _isReversalWarning
                              ? Icons.warning_amber_rounded
                              : (_isClockwise
                                    ? Icons.rotate_right
                                    : Icons.rotate_left),
                          color: _isReversalWarning
                              ? const Color(0xFFEF4444)
                              : (_isClockwise
                                    ? const Color(0xFF60A5FA)
                                    : const Color(0xFFF59E0B)),
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _isReversalWarning
                                    ? 'REVERSE VORTEX! (${_secondsUntilReversal}s)'
                                    : (_isClockwise
                                          ? 'Stir Clockwise (Build Deep Vortex)'
                                          : 'Stir Counter-Clockwise (Break & Chaos)'),
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: _isReversalWarning
                                      ? const Color(0xFFEF4444)
                                      : Colors.white,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _isReversalWarning
                                    ? 'Break the vortex crater now to create dynamic chaos!'
                                    : 'Vortex Cycle $_currentCycleIndex of $_totalCycles (${_secondsUntilReversal}s until reverse)',
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Main Circular Progress & Timer Display
                  Center(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 200,
                          height: 200,
                          child: CircularProgressIndicator(
                            value: progress,
                            strokeWidth: 8,
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.1,
                            ),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFF646CFF),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 175,
                          height: 175,
                          child: CircularProgressIndicator(
                            value: cycleProgress,
                            strokeWidth: 4,
                            backgroundColor: Colors.transparent,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              _isReversalWarning
                                  ? const Color(0xFFEF4444)
                                  : (_isClockwise
                                        ? const Color(0xFF60A5FA)
                                        : const Color(0xFFF59E0B)),
                            ),
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _formatTime(_remainingSeconds),
                              style: GoogleFonts.outfit(
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Cycle $_currentCycleIndex/$_totalCycles',
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF818CF8),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ±1 Minute Skip Controls
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ConstrainedBox(
                        constraints: const BoxConstraints(
                          minWidth: 48,
                          minHeight: 48,
                        ),
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white70,
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.2),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                          ),
                          onPressed: () => _skipSeconds(-60),
                          icon: const Icon(Icons.replay_10, size: 16),
                          label: Text(
                            '-1 min',
                            style: GoogleFonts.outfit(fontSize: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ConstrainedBox(
                        constraints: const BoxConstraints(
                          minWidth: 48,
                          minHeight: 48,
                        ),
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white70,
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.2),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                          ),
                          onPressed: () => _skipSeconds(60),
                          icon: const Icon(Icons.forward_10, size: 16),
                          label: Text(
                            '+1 min',
                            style: GoogleFonts.outfit(fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Main Timer Action Buttons (Play / Pause, Reset)
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 52,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isRunning
                                  ? const Color(0xFFEF4444)
                                        .withValues(alpha: 0.8)
                                  : const Color(0xFF646CFF),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: _toggleTimer,
                            icon: Icon(
                              _isRunning ? Icons.pause : Icons.play_arrow,
                            ),
                            label: Text(
                              _isRunning ? 'Pause Stirring' : 'Start Stirring',
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ConstrainedBox(
                        constraints: const BoxConstraints(
                          minWidth: 48,
                          minHeight: 52,
                        ),
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white70,
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.2),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: const EdgeInsets.all(14),
                          ),
                          onPressed: _resetTimer,
                          child: const Icon(Icons.refresh),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Goethean Dynamization & Application Guidance Section
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.auto_awesome,
                              size: 16,
                              color: Color(0xFF818CF8),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Goethean Dynamization Guidance',
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildGuidanceRow(
                          icon: Icons.water_drop_outlined,
                          iconColor: const Color(0xFF60A5FA),
                          title: 'Water Source & Warmth',
                          description: 'Clean rainwater recommended (or living spring water). Warm to approx. 35°C (blood warmth) before dynamizing. Avoid treated, chlorinated tap water.',
                        ),
                        const SizedBox(height: 10),
                        _buildGuidanceRow(
                          icon: Icons.nature_outlined,
                          iconColor: const Color(0xFFF59E0B),
                          title: 'Vessel Materiality',
                          description: 'Natural materials: Oak or larch wooden barrel, glazed earthenware crock, or hammered copper vat. Avoid synthetic plastic containers which dampen energetic resonance.',
                        ),
                        const SizedBox(height: 10),
                        _buildGuidanceRow(
                          customIcon: const BiodynamicIcon(
                            type: BiodynamicIconType.dynamizationVortex,
                            size: 14,
                            color: Color(0xFF818CF8),
                          ),
                          iconColor: const Color(0xFF818CF8),
                          title: 'Vortex & Dynamic Chaos',
                          description: 'Stir along perimeter to form a deep funnel reaching the bottom of the barrel, then reverse sharply to shatter into dynamic foaming chaos.',
                        ),
                        const SizedBox(height: 10),
                        _buildGuidanceRow(
                          icon: Icons.grain,
                          iconColor: const Color(0xFF10B981),
                          title: 'Droplet Atomization & Spraying',
                          description: _getDropletGuidanceForPrep(
                            _selectedPrep,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGuidanceRow({
    IconData? icon,
    Widget? customIcon,
    required Color iconColor,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: customIcon ?? Icon(icon, size: 14, color: iconColor),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  color: Colors.white70,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPrepTab(String title, StirringPrepType prep) {
    final isSelected = _selectedPrep == prep;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
      child: InkWell(
        onTap: () {
          if (!_isRunning) {
            setState(() {
              _setDurationForPrep(prep);
            });
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF646CFF).withValues(alpha: 0.3)
                : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF646CFF)
                  : Colors.white.withValues(alpha: 0.1),
            ),
          ),
          child: Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? Colors.white : Colors.white60,
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

class ControlPanel extends StatelessWidget {
  const ControlPanel({
    super.key,
    required this.hourText,
    required this.ampmText,
    required this.armed,
    required this.onToggleAmPm,
    required this.onArm,
    required this.onStop,
    required this.onTest,
    required this.isTesting,
    this.topContent, // <<< NEU
  });

  final String hourText; // z.B. "04:07"
  final String ampmText; // "AM" / "PM"
  final bool armed;
  final VoidCallback onToggleAmPm;
  final VoidCallback onArm;
  final VoidCallback onStop;
  final VoidCallback onTest;
  final bool isTesting;
  final Widget? topContent; // <<< NEU

  /// Wandelt hourText (12h, z.B. "04:07") + ampmText ("AM"/"PM")
  /// rein für die Anzeige in einen 24h-String um.
  String _display24h() {
    final parts = hourText.split(':');
    int h = int.tryParse(parts[0]) ?? 0;
    final m = parts.length > 1 ? parts[1] : '00';
    if (ampmText == 'AM' && h == 12) h = 0;
    if (ampmText == 'PM' && h != 12) h += 12;
    return '${h.toString().padLeft(2, '0')}:$m';
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final display = _display24h();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
                16, 8, 16, 8 + MediaQuery.of(context).padding.bottom),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Container(
                decoration: BoxDecoration(
                  color:
                      const Color(0xFF232323).withAlpha((0.82 * 255).round()),
                  boxShadow: const [
                    BoxShadow(
                        blurRadius: 18,
                        offset: Offset(0, 6),
                        color: Colors.black26)
                  ],
                  image: const DecorationImage(
                    image: AssetImage('assets/images/paw_shapes.png'),
                    fit: BoxFit.cover,
                    opacity: 0.18,
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (topContent != null) ...[
                      topContent!, // <<< NEU
                      const SizedBox(height: 8),
                    ],
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          display,
                          style: const TextStyle(
                            fontSize: 40,
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            shadows: [
                              Shadow(
                                  offset: Offset(0, 2),
                                  blurRadius: 4,
                                  color: Colors.black54),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _pillButton(
                          label: ampmText == 'AM'
                              ? loc.am
                              : (ampmText == 'PM' ? loc.pm : ampmText),
                          onTap: onToggleAmPm,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (armed)
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: () {
                            debugPrint(
                                'ControlPanel: Stop getappt -> onStop()');
                            onStop.call(); // <- WICHTIG: zentrales Stop aus main.dart
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                          ),
                          child: Text(loc.stopButton),
                        ),
                      )
                    else
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: _beigeButton(
                          icon: Icons.pets,
                          label: loc.setButton,
                          onTap: onArm,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========== kleine Helfer für Styles ===========
  static Widget _pillButton(
      {required String label, required VoidCallback onTap}) {
    return Material(
      color: const Color(0xFF2C2C2C),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 4), // kompakter
          child: Text(label,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }

  static Widget _beigeButton(
      {required IconData icon,
      required String label,
      required VoidCallback onTap}) {
    return Material(
      color: const Color(0xFFF1E5D7),
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: const Color(0xFF6A4E3B)),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF6A4E3B),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

}

import 'package:flutter/material.dart';
import '../audio/cat_alarm_player.dart';
import '../core/alarm_core.dart';

class ControlPanel extends StatelessWidget {
  const ControlPanel({
    super.key,
    required this.hourText,
    required this.ampmText,
    required this.nowText,
    required this.onToggleAmPm,
    required this.onArm,
    required this.onStop,
    required this.onTest,
    this.armed = false,
    this.isTesting = false,
  });

  final String hourText;   // z.B. "04:07"
  final String ampmText;   // "AM" / "PM"
  final String nowText;    // "Aktuelle Uhrzeit: 19:45:14"
  final VoidCallback onToggleAmPm;
  final VoidCallback onArm;
  final VoidCallback onStop;
  final VoidCallback onTest;
  final bool armed;
  final bool isTesting;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 8 + MediaQuery.of(context).padding.bottom),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF232323).withOpacity(0.82),
                  boxShadow: const [BoxShadow(blurRadius: 18, offset: Offset(0, 6), color: Colors.black26)],
                  image: const DecorationImage(
                    image: AssetImage('assets/images/paw_shapes.png'),
                    fit: BoxFit.cover,
                    opacity: 0.18,
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      hourText,
                      style: const TextStyle(
                        fontSize: 40,
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        shadows: [
                          Shadow(offset: Offset(0, 2), blurRadius: 4, color: Colors.black54),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          ampmText,
                          style: const TextStyle(
                            fontSize: 22,
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            shadows: [Shadow(offset: Offset(0, 1), blurRadius: 2, color: Colors.black45)],
                          ),
                        ),
                        const SizedBox(width: 12),
                        _pillButton(label: 'AM/PM', onTap: onToggleAmPm),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      nowText,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        shadows: [Shadow(offset: Offset(0, 1), blurRadius: 2, color: Colors.black45)],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: _beigeButton(
                            icon: Icons.pets,
                            label: armed ? 'Alarm' : 'Stellen',
                            onTap: onArm,
                          ),
                        ),
                        const SizedBox(width: 2), // reduziert
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: armed
                                ? () {
                                    debugPrint('ControlPanel: Stop getappt -> onStop()');
                                    onStop.call(); // <- WICHTIG: zentrales Stop aus main.dart
                                  }
                                : null, // disabled wenn nicht armed
                            icon: const Icon(Icons.stop),
                            label: Text(armed ? 'Stopp' : 'Aus'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: armed ? Colors.red : Colors.grey,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 2), // reduziert
                        Expanded(
                          child: _ghostButton(
                            label: 'Test',
                            color: const Color(0xFFF3A547),
                            onTap: onTest,
                          ),
                        ),
                      ],
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
  static Widget _pillButton({required String label, required VoidCallback onTap}) {
    return Material(
      color: const Color(0xFF2C2C2C),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4), // kompakter
          child: Text('AM/PM', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }

  static Widget _beigeButton({required IconData icon, required String label, required VoidCallback onTap}) {
    return Material(
      color: const Color(0xFFF1E5D7),
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12), // reduziert
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

  static Widget _ghostButton({required String label, required Color color, required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12), // reduziert
          child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w800)),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../audio/cat_alarm_player.dart';
import '../l10n/app_localizations.dart';

class AudioActiveBanner extends StatelessWidget {
  const AudioActiveBanner({super.key, required this.isTesting});

  final bool isTesting;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: CatAlarmPlayer.I.isActive,
      builder: (context, playerActive, _) {
        final active = playerActive || isTesting;
        if (!active) return const SizedBox.shrink();
        final loc = AppLocalizations.of(context)!;
        return Align(
          alignment: Alignment.topCenter,
          child: SafeArea(
            child: Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFE53935)
                    .withAlpha((0.95 * 255).round()),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                loc.audioActiveBanner,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        );
      },
    );
  }
}

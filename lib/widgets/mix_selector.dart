import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

enum AlarmMix { soft, standard, power }

class MixSelector extends StatelessWidget {
  const MixSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final AlarmMix selected;
  final ValueChanged<AlarmMix> onChanged;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Row(
      children: [
        Expanded(
          child: _MixCard(
            icon: Icons.favorite_rounded,
            label: loc.soft,
            selected: selected == AlarmMix.soft,
            onTap: () => onChanged(AlarmMix.soft),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MixCard(
            icon: Icons.music_note_rounded,
            label: loc.standard,
            selected: selected == AlarmMix.standard,
            onTap: () => onChanged(AlarmMix.standard),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MixCard(
            icon: Icons.bolt_rounded,
            label: loc.power,
            selected: selected == AlarmMix.power,
            onTap: () => onChanged(AlarmMix.power),
          ),
        ),
      ],
    );
  }
}

class _MixCard extends StatelessWidget {
  const _MixCard({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  static const Color _amber = Color(0xFFE8A65A);

  @override
  Widget build(BuildContext context) {
    final bg = selected
        ? const Color(0xFF2A2347).withAlpha(220)
        : const Color(0xFF1F1B36).withAlpha(180);
    final border = selected
        ? _amber.withAlpha(220)
        : Colors.white.withAlpha(20);
    final iconColor = selected ? _amber : Colors.white.withAlpha(180);

    return SizedBox(
      height: 84,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border, width: 1.4),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: _amber.withAlpha(80),
                    blurRadius: 18,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: iconColor, size: 26),
                  const SizedBox(height: 6),
                  Text(
                    label,
                    style: TextStyle(
                      color: selected ? Colors.white : Colors.white70,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      letterSpacing: 0.2,
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
}

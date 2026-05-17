import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

enum AlarmMix { soft, standard, power }

class MixSelector extends StatelessWidget {
  const MixSelector({
    super.key,
    required this.selected,
    required this.onChanged,
    this.compact = false,
  });

  final AlarmMix selected;
  final ValueChanged<AlarmMix> onChanged;

  /// Kompaktere Karten (kleinere Höhe, Icon- und Textgröße) für sehr enge
  /// Layouts wie Phone-Querformat. Default false → Phone-Hochformat /
  /// iPad-Hochformat sind pixel-identisch zu vorher.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final gap = compact ? 8.0 : 10.0;
    return Row(
      children: [
        Expanded(
          child: _MixCard(
            icon: Icons.favorite_rounded,
            label: loc.soft,
            selected: selected == AlarmMix.soft,
            onTap: () => onChanged(AlarmMix.soft),
            compact: compact,
          ),
        ),
        SizedBox(width: gap),
        Expanded(
          child: _MixCard(
            icon: Icons.music_note_rounded,
            label: loc.standard,
            selected: selected == AlarmMix.standard,
            onTap: () => onChanged(AlarmMix.standard),
            compact: compact,
          ),
        ),
        SizedBox(width: gap),
        Expanded(
          child: _MixCard(
            icon: Icons.bolt_rounded,
            label: loc.power,
            selected: selected == AlarmMix.power,
            onTap: () => onChanged(AlarmMix.power),
            compact: compact,
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
    this.compact = false,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool compact;

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

    final cardHeight = compact ? 54.0 : 84.0;
    final radius = compact ? 14.0 : 20.0;
    final paddingV = compact ? 6.0 : 12.0;
    final iconSize = compact ? 18.0 : 26.0;
    final spacing = compact ? 2.0 : 6.0;
    final fontSize = compact ? 11.0 : 14.0;

    return SizedBox(
      height: cardHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: border, width: 1.4),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: _amber.withAlpha(80),
                    blurRadius: compact ? 12 : 18,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(radius),
          child: InkWell(
            borderRadius: BorderRadius.circular(radius),
            onTap: onTap,
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: paddingV, horizontal: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: iconColor, size: iconSize),
                  SizedBox(height: spacing),
                  Text(
                    label,
                    style: TextStyle(
                      color: selected ? Colors.white : Colors.white70,
                      fontWeight: FontWeight.w600,
                      fontSize: fontSize,
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

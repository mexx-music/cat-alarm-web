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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          loc.selectTone,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ChoiceChip(
              label: Text(loc.soft),
              selected: selected == AlarmMix.soft,
              onSelected: (_) => onChanged(AlarmMix.soft),
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              label: Text(loc.standard),
              selected: selected == AlarmMix.standard,
              onSelected: (_) => onChanged(AlarmMix.standard),
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              label: Text(loc.power),
              selected: selected == AlarmMix.power,
              onSelected: (_) => onChanged(AlarmMix.power),
            ),
          ],
        ),
        const SizedBox(height: 6),
        // Entfernt: Text zur aktuellen Auswahl und Datei
      ],
    );
  }
}

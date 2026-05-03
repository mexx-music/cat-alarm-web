String fmt2(int v) => v.toString().padLeft(2, '0');

String formatHour12(int hour, int minute) {
  final h = hour % 12 == 0 ? 12 : hour % 12;
  return '${fmt2(h)}:${fmt2(minute)}';
}

String amPm(int hour) => hour < 12 ? 'AM' : 'PM';

import 'package:flutter/widgets.dart';

/// Tablet erkannt anhand der kürzeren Bildschirmkante (iPad Mini ≈ 768 dp,
/// iPad Pro 13" ≈ 1024 dp; iPhone Pro Max ≈ 430 dp → klar unter 600).
bool isTablet(BuildContext context) =>
    MediaQuery.sizeOf(context).shortestSide >= 600;

bool isPortrait(BuildContext context) {
  final s = MediaQuery.sizeOf(context);
  return s.height >= s.width;
}

bool isTabletPortrait(BuildContext context) =>
    isTablet(context) && isPortrait(context);

/// Echtes Phone-Landscape (kleines Querformat).
/// shortestSide < 600 = Phone. width > height = landscape orientation.
bool isPhoneLandscape(BuildContext context) {
  final s = MediaQuery.sizeOf(context);
  return s.shortestSide < 600 && s.width > s.height;
}

/// Maximale Breite für Text-/Button-Kolumnen auf dem iPad Hochformat.
/// Auf dem iPhone bleibt `double.infinity` → bestehendes Layout unverändert.
double maxContentWidth(BuildContext context) =>
    isTabletPortrait(context) ? 560.0 : double.infinity;

/// Begrenzt [child] horizontal nur auf Tablet-Hochformat und zentriert es.
/// Auf dem iPhone wird das Kind unverändert zurückgegeben — kein zusätzliches
/// Center/ConstrainedBox in der Render-Pipeline.
class MaxContentBox extends StatelessWidget {
  const MaxContentBox({super.key, required this.child, this.maxWidth});

  final Widget child;

  /// Optional override; standardmäßig wird [maxContentWidth] verwendet.
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    if (!isTabletPortrait(context)) return child;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth ?? maxContentWidth(context)),
        child: child,
      ),
    );
  }
}

/// Hintergrundbild des Armed-/Waiting-Screens.
/// Bewusst auf beiden Plattformen `catwait.png` (schlafende Katze) — passt
/// zur Wartestimmung. `catipad.png` bleibt dem Setup-Screen vorbehalten.
String armedBackgroundAsset(BuildContext context) =>
    'assets/images/catwait.png';

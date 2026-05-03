// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:js' as js;

bool get isPwaInstallAvailable {
  try {
    return js.context['deferredPrompt'] != null;
  } catch (_) {
    return false;
  }
}

bool get isIosSafari {
  try {
    final ua = html.window.navigator.userAgent.toLowerCase();
    final isIos = ua.contains('iphone') ||
        ua.contains('ipad') ||
        ua.contains('ipod');
    final isStandalone =
        html.window.matchMedia('(display-mode: standalone)').matches;
    return isIos && !isStandalone;
  } catch (_) {
    return false;
  }
}

Future<void> promptPwaInstall() async {
  try {
    final prompt = js.context['deferredPrompt'];
    if (prompt == null) return;
    (prompt as js.JsObject).callMethod('prompt');
    js.context['deferredPrompt'] = null;
  } catch (_) {}
}

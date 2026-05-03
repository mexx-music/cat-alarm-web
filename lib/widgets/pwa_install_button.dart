import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../utils/pwa_helper.dart';

class PwaInstallButton extends StatefulWidget {
  const PwaInstallButton({super.key});

  @override
  State<PwaInstallButton> createState() => _PwaInstallButtonState();
}

class _PwaInstallButtonState extends State<PwaInstallButton> {
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    // beforeinstallprompt fires async after page load — trigger one rebuild
    if (kIsWeb) {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb || _dismissed) return const SizedBox.shrink();

    if (isPwaInstallAvailable) {
      return _banner(
        text: 'App installieren',
        onTap: () async {
          await promptPwaInstall();
          if (mounted) setState(() => _dismissed = true);
        },
      );
    }

    if (isIosSafari) {
      return _banner(
        text: 'Teilen → Zum Home-Bildschirm',
        onTap: null,
      );
    }

    return const SizedBox.shrink();
  }

  Widget _banner({required String text, VoidCallback? onTap}) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12, left: 16, right: 16),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha((0.10 * 255).round()),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white24),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.add_to_home_screen,
                      color: Colors.white60, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    text,
                    style: const TextStyle(
                        color: Colors.white60, fontSize: 12),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () => setState(() => _dismissed = true),
                    child: const Icon(Icons.close,
                        color: Colors.white38, size: 14),
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

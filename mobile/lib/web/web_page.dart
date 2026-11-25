import 'package:material_ui/material_ui.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../theme.dart';
import 'web_view_factory.dart';

/// Shows a [WebHost] with a thin load bar and an offline screen.
class WebPage extends StatelessWidget {
  const WebPage({super.key, required this.host});

  final WebHost host;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: host,
      builder: (context, _) => Stack(
        children: [
          WebViewWidget(controller: host.controller),
          if (host.progress < 100 && !host.offline)
            LinearProgressIndicator(
              value: host.progress / 100,
              minHeight: 2,
              color: atsuete,
              backgroundColor: Colors.transparent,
            ),
          if (host.offline) OfflineView(onRetry: host.retry),
        ],
      ),
    );
  }
}

class OfflineView extends StatelessWidget {
  const OfflineView({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: paper,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('assets/splash.png', width: 72, height: 72),
              const SizedBox(height: 24),
              Text('Walay koneksyon', style: display(26, weight: 600)),
              const SizedBox(height: 8),
              Text(
                "You're offline. Check your internet connection and try again.",
                textAlign: TextAlign.center,
                style: body(15, color: muted),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: onRetry,
                style: FilledButton.styleFrom(
                  backgroundColor: atsuete,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                ),
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

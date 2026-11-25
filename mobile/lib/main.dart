import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
import 'session/app_session.dart';
import 'theme.dart';
import 'web/bridge.dart';
import 'web/web_page.dart';
import 'web/web_view_factory.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // The key is used as-is, so the legacy anon key works here too.
  await Supabase.initialize(url: supabaseUrl, publishableKey: supabaseAnonKey);
  runApp(CraftCebuApp(session: AppSession()));
}

class CraftCebuApp extends StatelessWidget {
  const CraftCebuApp({super.key, required this.session});

  final AppSession session;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CraftCebu',
      debugShowCheckedModeBanner: false,
      theme: craftCebuTheme(),
      home: ShellScreen(session: session),
    );
  }
}

/// Temporary full-screen web view; the native tab shell replaces it.
class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key, required this.session});

  final AppSession session;

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  WebHost? _host;
  WebBridge? _bridge;

  @override
  void initState() {
    super.initState();
    WebHost.create().then((host) async {
      _bridge = WebBridge(
        host.controller,
        widget.session,
        BridgeHandlers(onLogin: (_) {}, onOpenProduct: (_) {}, onOpenShop: (_) {}, onCartChanged: () {}),
      );
      await host.load(homeUrl);
      if (mounted) setState(() => _host = host);
    });
  }

  @override
  void dispose() {
    _bridge?.dispose();
    super.dispose();
  }

  Future<void> _handleBack() async {
    final controller = _host?.controller;
    if (controller != null && await controller.canGoBack()) {
      await controller.goBack();
    } else {
      await SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final host = _host;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(body: SafeArea(child: host == null ? const SizedBox.expand() : WebPage(host: host))),
    );
  }
}

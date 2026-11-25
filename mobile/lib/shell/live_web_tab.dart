import 'package:material_ui/material_ui.dart';

import '../config.dart';
import '../session/app_session.dart';
import '../web/bridge.dart';
import '../web/web_page.dart';
import '../web/web_view_factory.dart';
import 'tab_shell.dart';

/// A real web view of the site with the bridge attached.
class LiveWebTab implements WebTabDriver {
  LiveWebTab(AppSession session, BridgeHandlers handlers, {String initialPath = '/'}) {
    _host = WebHost.create().then((host) async {
      _bridge = WebBridge(host.controller, session, handlers);
      await host.load('$homeUrl$initialPath');
      return host;
    });
  }

  late final Future<WebHost> _host;
  WebBridge? _bridge;

  @override
  Widget build(BuildContext context) => FutureBuilder(
        future: _host,
        builder: (context, snap) => snap.data == null ? const SizedBox.expand() : WebPage(host: snap.data!),
      );

  @override
  Future<void> navigate(String path) async {
    await _host;
    await _bridge!.navigate(path);
  }

  @override
  Future<void> reloadCart() async {
    await _host;
    await _bridge!.reloadCart();
  }

  @override
  Future<String?> currentPath() async {
    final url = await (await _host).controller.currentUrl();
    final uri = url == null ? null : Uri.tryParse(url);
    return uri == null ? null : '${uri.path.isEmpty ? '/' : uri.path}${uri.hasQuery ? '?${uri.query}' : ''}';
  }

  @override
  Future<bool> goBack() async {
    final controller = (await _host).controller;
    if (!await controller.canGoBack()) return false;
    await controller.goBack();
    return true;
  }

  @override
  void dispose() => _bridge?.dispose();
}

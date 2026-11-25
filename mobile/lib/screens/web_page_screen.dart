import 'package:material_ui/material_ui.dart';

import '../shell/live_web_tab.dart';
import '../shell/tab_shell.dart';
import '../theme.dart';
import '../web/bridge.dart';

/// A site page pushed over the tabs (Seller Centre, Edit profile, and so on),
/// with its own short-lived web view and bridge.
class WebPageScreen extends StatefulWidget {
  const WebPageScreen({super.key, required this.path});

  final String path;

  @override
  State<WebPageScreen> createState() => _WebPageScreenState();
}

class _WebPageScreenState extends State<WebPageScreen> {
  LiveWebTab? _web;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_web != null) return;
    final scope = TabShellScope.of(context);
    _web = LiveWebTab(
      scope.services.session,
      BridgeHandlers(
        onLogin: (returnTo) async {
          if (await scope.actions.requireSignIn() && (await _web?.pushSession() ?? false)) await _web?.navigate(returnTo);
        },
        onOpenProduct: scope.actions.openProduct,
        onOpenShop: (filters) {
          Navigator.of(context).maybePop();
          scope.actions.openShop(filters);
        },
        onCartChanged: scope.services.refreshCartCount,
      ),
      initialPath: widget.path,
    );
  }

  @override
  void dispose() {
    _web?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      // Back steps through the site's pages first, then closes.
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (!await _web!.goBack()) navigator.pop();
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: paper,
          surfaceTintColor: paper,
          leading: IconButton(tooltip: 'Close', icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
        ),
        body: SafeArea(top: false, child: _web!.build(context)),
      ),
    );
  }
}

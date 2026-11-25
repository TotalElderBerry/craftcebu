import 'dart:async';
import 'dart:convert';

import 'package:webview_flutter/webview_flutter.dart';

import '../config.dart';
import '../session/app_session.dart';

/// A message from the site (src/lib/app/bridge.ts) over the CraftCebuNative
/// JavaScript channel.
sealed class BridgeMessage {
  const BridgeMessage();

  /// Null for anything that isn't a message we know.
  static BridgeMessage? parse(String raw) {
    final Object? json;
    try {
      json = jsonDecode(raw);
    } on FormatException {
      return null;
    }
    if (json is! Map<String, dynamic>) return null;
    final map = json;
    String? text(String key) => switch (map[key]) {
          final String v when v.isNotEmpty => v,
          _ => null,
        };
    return switch (map['type']) {
      'ready' => const Ready(),
      'needToken' => const NeedToken(),
      'signOut' => const SignOutRequest(),
      'login' => LoginRequest(text('returnTo') ?? '/'),
      'openProduct' when text('slug') != null => OpenProduct(text('slug')!),
      'openShop' => OpenShop(category: text('category'), town: text('town'), q: text('q')),
      'cartChanged' => const CartChanged(),
      _ => null,
    };
  }
}

class Ready extends BridgeMessage {
  const Ready();
}

class NeedToken extends BridgeMessage {
  const NeedToken();
}

class SignOutRequest extends BridgeMessage {
  const SignOutRequest();
}

class LoginRequest extends BridgeMessage {
  const LoginRequest(this.returnTo);
  final String returnTo;
}

class OpenProduct extends BridgeMessage {
  const OpenProduct(this.slug);
  final String slug;
}

/// Shop filters as the site's /shop URL has them; town is the town's name.
class OpenShop extends BridgeMessage {
  const OpenShop({this.category, this.town, this.q});
  final String? category;
  final String? town;
  final String? q;
}

class CartChanged extends BridgeMessage {
  const CartChanged();
}

/// What the app does with the messages a page can't handle itself.
class BridgeHandlers {
  const BridgeHandlers({
    required this.onLogin,
    required this.onOpenProduct,
    required this.onOpenShop,
    required this.onCartChanged,
  });

  final void Function(String returnTo) onLogin;
  final void Function(String slug) onOpenProduct;
  final void Function(OpenShop filters) onOpenShop;
  final void Function() onCartChanged;
}

// Values reach the page as JSON literals, never pasted into code as text.
String setSessionScript(Map<String, Object?> payload) => 'window.craftcebu?.setSession(${jsonEncode(payload)})';
String _navigateScript(String path) => 'window.craftcebu?.navigate(${jsonEncode(path)})';
const _clearSessionScript = 'window.craftcebu?.clearSession()';
const _reloadCartScript = 'window.craftcebu?.reloadCart()';

/// The script that hands a web view the current session: set it, clear it,
/// or null to leave the page as it is (the server couldn't be reached).
Future<String?> sessionScriptFor(AppSession session) async {
  try {
    final payload = await session.webSessionPayload();
    return payload == null ? _clearSessionScript : setSessionScript(payload);
  } on SessionUnavailable {
    return null;
  }
}

/// True only for pages of the CraftCebu site itself (same scheme, host and
/// port as [home]). Payment, bank and other pages never get the session.
bool isSiteUrl(String? url, String home) {
  final page = url == null ? null : Uri.tryParse(url);
  final site = Uri.parse(home);
  return page != null && page.scheme == site.scheme && page.host == site.host && page.port == site.port;
}

/// Connects one web view to the app: lends it the session, and passes its
/// requests to the native screens.
class WebBridge {
  /// Call before the page's first load, so the channel exists when it boots.
  WebBridge(this.controller, this.session, this.handlers) {
    controller.addJavaScriptChannel('CraftCebuNative', onMessageReceived: (m) => _handle(m.message));
    session.addListener(_onSessionChanged);
  }

  final WebViewController controller;
  final AppSession session;
  final BridgeHandlers handlers;

  void dispose() => session.removeListener(_onSessionChanged);

  void _onSessionChanged() => unawaited(pushSession());

  Future<bool> _onSite() async => isSiteUrl(await controller.currentUrl(), homeUrl);

  Future<void> _handle(String raw) async {
    if (!await _onSite()) return;
    switch (BridgeMessage.parse(raw)) {
      case Ready() || NeedToken():
        await pushSession();
      case SignOutRequest():
        await session.signOut();
      case LoginRequest(:final returnTo):
        handlers.onLogin(returnTo);
      case OpenProduct(:final slug):
        handlers.onOpenProduct(slug);
      case final OpenShop filters:
        handlers.onOpenShop(filters);
      case CartChanged():
        handlers.onCartChanged();
      case null:
        break;
    }
  }

  /// Lends the page the current session; true when a session was set.
  Future<bool> pushSession() async {
    if (!await _onSite()) return false;
    final script = await sessionScriptFor(session);
    if (script == null) return false;
    await _run(script);
    return script != _clearSessionScript;
  }

  Future<void> navigate(String path) => _run(_navigateScript(path));

  Future<void> reloadCart() => _run(_reloadCartScript);

  // A page that is still loading has no window.craftcebu yet; it asks for the
  // session itself with 'ready' once it boots.
  Future<void> _run(String script) async {
    try {
      await controller.runJavaScript(script);
    } catch (_) {}
  }
}

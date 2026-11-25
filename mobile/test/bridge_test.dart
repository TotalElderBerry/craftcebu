import 'dart:convert';

import 'package:craftcebu_mobile/session/app_session.dart';
import 'package:craftcebu_mobile/web/bridge.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

void main() {
  test('parses openProduct', () {
    final msg = BridgeMessage.parse('{"type":"openProduct","slug":"banig"}');
    expect(msg, isA<OpenProduct>());
    expect((msg! as OpenProduct).slug, 'banig');
  });

  test('parses openShop with a town name', () {
    final msg = BridgeMessage.parse('{"type":"openShop","category":"pottery","town":"Argao"}')! as OpenShop;
    expect(msg.category, 'pottery');
    expect(msg.town, 'Argao');
    expect(msg.q, isNull);
  });

  test('parses login with returnTo', () {
    final msg = BridgeMessage.parse('{"type":"login","returnTo":"/orders"}');
    expect((msg! as LoginRequest).returnTo, '/orders');
  });

  test('unknown type returns null', () {
    expect(BridgeMessage.parse('{"type":"launchRockets"}'), isNull);
  });

  test('bad json returns null', () {
    expect(BridgeMessage.parse('not json'), isNull);
    expect(BridgeMessage.parse('[1,2]'), isNull);
  });

  test('setSession script escapes values', () {
    const token = "a'\"</script>\\";
    final script = setSessionScript({'access_token': token});
    final arg = RegExp(r'setSession\((.*)\)$').firstMatch(script)!.group(1)!;
    expect((jsonDecode(arg) as Map)['access_token'], token);
  });

  test('session script sets the session for a signed-in shopper', () async {
    final script = await sessionScriptFor(FakeSession(webPayload: {'access_token': 't'}));
    expect(script, startsWith('window.craftcebu?.setSession('));
  });

  test('session script clears the session when signed out', () async {
    expect(await sessionScriptFor(FakeSession()), 'window.craftcebu?.clearSession()');
  });

  test('no session script when a refresh could not reach the server', () async {
    expect(await sessionScriptFor(FakeSession(webPayload: const SessionUnavailable())), isNull);
  });

  test('only the CraftCebu site gets the session', () {
    const home = 'https://craftcebu.vercel.app';
    expect(isSiteUrl('https://craftcebu.vercel.app/cart', home), isTrue);
    expect(isSiteUrl('https://craftcebu.vercel.app', home), isTrue);
    expect(isSiteUrl('https://payments.maya.ph/checkout', home), isFalse);
    expect(isSiteUrl('https://craftcebu.vercel.app.evil.com/', home), isFalse);
    expect(isSiteUrl('http://craftcebu.vercel.app/', home), isFalse);
    expect(isSiteUrl(null, home), isFalse);
    expect(isSiteUrl('http://localhost:5173/orders', 'http://localhost:5173'), isTrue);
  });
}

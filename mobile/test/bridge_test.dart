import 'dart:convert';

import 'package:craftcebu_mobile/web/bridge.dart';
import 'package:flutter_test/flutter_test.dart';

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
}

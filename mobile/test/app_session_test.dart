import 'dart:convert';

import 'package:craftcebu_mobile/session/app_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// An unsigned JWT is enough: the session only reads its `exp` claim.
String fakeJwt(int exp) {
  String part(Map<String, Object> json) => base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
  return '${part({'alg': 'none'})}.${part({'exp': exp, 'sub': 'u1'})}.sig';
}

Session fakeSession() => Session(
      accessToken: fakeJwt(2000000000),
      refreshToken: 'r',
      tokenType: 'bearer',
      user: const User(
        id: 'u1',
        appMetadata: {},
        userMetadata: {'full_name': 'Maria'},
        aud: 'authenticated',
        createdAt: '2026-11-25T00:00:00Z',
        email: 'maria@test.local',
      ),
    );

void main() {
  test('payload never includes refresh_token', () {
    final payload = sessionPayloadFor(fakeSession());
    expect(payload.containsKey('refresh_token'), isFalse);
    expect(jsonEncode(payload), isNot(contains('"r"')));
    expect(payload['access_token'], fakeSession().accessToken);
    expect(payload['expires_at'], 2000000000);
  });

  test('payload carries the user id', () {
    final user = sessionPayloadFor(fakeSession())['user'] as Map<String, Object?>;
    expect(user['id'], 'u1');
    expect(user['email'], 'maria@test.local');
    expect(user['user_metadata'], {'full_name': 'Maria'});
  });
}

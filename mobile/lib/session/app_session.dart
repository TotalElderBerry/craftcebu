import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config.dart';

/// The parts of a profile the app needs to decide what to show.
class Profile {
  const Profile({required this.role, required this.fullName, this.email, this.artisanStatus});

  final String role; // buyer, artisan or owner
  final String fullName;
  final String? email;
  final String? artisanStatus; // pending, verified, rejected, suspended, or null with no shop
}

/// The session couldn't be refreshed because the server was out of reach.
/// The shopper is still signed in; web views keep what they have for now.
class SessionUnavailable implements Exception {
  const SessionUnavailable();
}

class BannedException implements Exception {
  @override
  String toString() => 'This account has been suspended. Email hello@craftcebu.test if you think this is a mistake.';
}

// Ask for a new token once the current one has a minute or less left
// (the site uses the same margin).
const tokenMarginSeconds = 60;

/// What the site may hold: a short-lived access token and who it belongs to.
/// Never the refresh token, which only the app keeps and spends.
Map<String, Object?> sessionPayloadFor(Session s) => {
      'access_token': s.accessToken,
      'expires_at': s.expiresAt,
      'user': {'id': s.user.id, 'email': s.user.email, 'user_metadata': s.user.userMetadata},
    };

/// The app's sign-in, which the web views borrow through the bridge.
class AppSession extends ChangeNotifier {
  AppSession([SupabaseClient? client]) : _client = client ?? Supabase.instance.client {
    _user = _auth.currentUser;
    if (_user != null) _loadProfile();
    _auth.onAuthStateChange.listen((state) async {
      final next = state.session?.user;
      final changedUser = next?.id != _user?.id;
      _user = next;
      if (changedUser) {
        profile = null;
        if (next != null) await _loadProfile();
      }
      // Token refreshes notify too, so web views get the new token.
      notifyListeners();
    });
  }

  final SupabaseClient _client;
  GoTrueClient get _auth => _client.auth;

  User? _user;
  User? get user => _user;
  Profile? profile;
  bool get signedIn => _user != null;

  Future<void> _loadProfile() async {
    final id = _user?.id;
    if (id == null) return;
    final row = await _client.from('profiles').select('role, full_name, email, is_banned').eq('id', id).maybeSingle();
    if (row == null) return;
    if (row['is_banned'] == true) {
      await signOut();
      throw BannedException();
    }
    final shop = await _client.from('artisans').select('status').eq('profile_id', id).maybeSingle();
    profile = Profile(
      role: row['role'] as String,
      fullName: row['full_name'] as String? ?? '',
      email: row['email'] as String?,
      artisanStatus: shop?['status'] as String?,
    );
    notifyListeners();
  }

  Future<void> signIn(String email, String password) async {
    final res = await _auth.signInWithPassword(email: email, password: password);
    _user = res.user;
    await _loadProfile();
  }

  /// Returns true when the account needs email confirmation first.
  Future<bool> signUp(String fullName, String email, String password) async {
    final res = await _auth.signUp(email: email, password: password, data: {'full_name': fullName});
    return res.session == null;
  }

  Future<void> sendPasswordReset(String email) =>
      _auth.resetPasswordForEmail(email, redirectTo: '$homeUrl/reset-password');

  Future<void> signOut() async {
    await _auth.signOut();
    _user = null;
    profile = null;
    notifyListeners();
  }

  /// The session for a web view, refreshed first when it is about to expire.
  /// Null when signed out or when the refresh is refused; throws
  /// [SessionUnavailable] when the server can't be reached.
  Future<Map<String, Object?>?> webSessionPayload() async {
    var session = _auth.currentSession;
    if (session == null) return null;
    final expiresAt = session.expiresAt ?? 0;
    if (expiresAt - DateTime.now().millisecondsSinceEpoch ~/ 1000 <= tokenMarginSeconds) {
      try {
        session = (await _auth.refreshSession()).session;
      } on AuthRetryableFetchException {
        throw const SessionUnavailable();
      } on AuthException {
        return null;
      }
      if (session == null) return null;
    }
    return sessionPayloadFor(session);
  }
}

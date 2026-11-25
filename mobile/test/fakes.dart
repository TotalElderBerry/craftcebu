import 'package:craftcebu_mobile/data/cart_repo.dart';
import 'package:craftcebu_mobile/session/app_session.dart';
import 'package:craftcebu_mobile/shell/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FakeSession extends ChangeNotifier implements AppSession {
  FakeSession({this.signedInAs, this.profile, this.signInError});

  String? signedInAs;
  @override
  Profile? profile;
  Object? signInError;
  final calls = <String>[];

  @override
  User? get user => signedInAs == null
      ? null
      : User(id: signedInAs!, appMetadata: const {}, userMetadata: const {}, aud: 'authenticated', createdAt: '', email: '$signedInAs@test.local');
  @override
  bool get signedIn => signedInAs != null;

  @override
  Future<void> signIn(String email, String password) async {
    calls.add('signIn');
    if (signInError != null) throw signInError!;
    signedInAs = 'u1';
    notifyListeners();
  }

  @override
  Future<bool> signUp(String fullName, String email, String password) async {
    calls.add('signUp');
    return true;
  }

  @override
  Future<void> sendPasswordReset(String email) async => calls.add('reset');

  @override
  Future<void> signOut() async {
    calls.add('signOut');
    signedInAs = null;
    profile = null;
    notifyListeners();
  }

  @override
  Future<Map<String, Object?>?> webSessionPayload() async => null;
}

class FakeCart implements CartRepo {
  FakeCart({this.count = 0, List<int>? addResults}) : addResults = addResults ?? [];

  int count;
  final List<int> addResults;
  final calls = <String>[];

  @override
  Future<int> addToCart(String productId, int qty) async {
    calls.add('add $productId $qty');
    return addResults.isEmpty ? qty : addResults.removeAt(0);
  }

  @override
  Future<int> pieceCount() async => count;
}

AppServices fakeServices({AppSession? session, CartRepo? cart}) =>
    AppServices(session: session ?? FakeSession(), cart: cart ?? FakeCart());

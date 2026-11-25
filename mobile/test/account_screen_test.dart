import 'package:craftcebu_mobile/screens/account/account_screen.dart';
import 'package:craftcebu_mobile/screens/account/sign_in_screen.dart';
import 'package:craftcebu_mobile/session/app_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'fakes.dart';

Future<void> pumpAccount(WidgetTester tester, FakeSession session, {FakeActions? actions}) =>
    pumpTall(tester, inShell(const AccountScreen(), services: fakeServices(session: session), actions: actions ?? FakeActions(session: session)));

void main() {
  testWidgets('signed out shows sign-in card', (tester) async {
    await pumpAccount(tester, FakeSession());
    expect(find.text('Sign in or create an account'), findsOneWidget);
    expect(find.text('Sign out'), findsNothing);
  });

  testWidgets('buyer sees Sell on CraftCebu but not Seller Centre', (tester) async {
    await pumpAccount(tester, FakeSession(signedInAs: 'u1', profile: const Profile(role: 'buyer', fullName: 'Maria Santos')));
    expect(find.text('Maria Santos'), findsOneWidget);
    expect(find.text('Sell on CraftCebu'), findsOneWidget);
    expect(find.text('Seller Centre'), findsNothing);
    expect(find.text('Admin Centre'), findsNothing);
  });

  testWidgets('verified artisan sees Seller Centre, not Sell', (tester) async {
    await pumpAccount(tester, FakeSession(signedInAs: 'u1', profile: const Profile(role: 'artisan', fullName: 'Lola', artisanStatus: 'verified')));
    expect(find.text('Seller Centre'), findsOneWidget);
    expect(find.text('Sell on CraftCebu'), findsNothing);
  });

  testWidgets('owner sees Admin Centre', (tester) async {
    await pumpAccount(tester, FakeSession(signedInAs: 'u1', profile: const Profile(role: 'owner', fullName: 'Brian')));
    expect(find.text('Admin Centre'), findsOneWidget);
    expect(find.text('Seller Centre'), findsOneWidget);
  });

  testWidgets('rows open their web page', (tester) async {
    final session = FakeSession(signedInAs: 'u1', profile: const Profile(role: 'buyer', fullName: 'Maria'));
    final actions = FakeActions(session: session);
    await pumpAccount(tester, session, actions: actions);
    await tester.tap(find.text('Saved pieces'));
    expect(actions.log, contains('openWebPage /wishlist'));
  });

  testWidgets('sign out signs the session out', (tester) async {
    final session = FakeSession(signedInAs: 'u1', profile: const Profile(role: 'buyer', fullName: 'Maria'));
    await pumpAccount(tester, session);
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(session.calls, contains('signOut'));
    expect(find.text('Sign in or create an account'), findsOneWidget);
  });

  testWidgets('sign-in shows the suspended message for a banned account', (tester) async {
    final session = FakeSession(signInError: BannedException());
    await pumpTall(tester, inShell(const SignInScreen(), services: fakeServices(session: session), actions: FakeActions()));
    await tester.enterText(find.byKey(const ValueKey('email')), 'maria@test.local');
    await tester.enterText(find.byKey(const ValueKey('password')), 'secret123');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();
    expect(find.textContaining('This account has been suspended.'), findsOneWidget);
  });

  testWidgets('sign-up that needs confirmation says to check email', (tester) async {
    await pumpTall(tester, inShell(const SignInScreen(), services: fakeServices(), actions: FakeActions()));
    await tester.tap(find.text('Create an account'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('name')), 'Maria Santos');
    await tester.enterText(find.byKey(const ValueKey('email')), 'maria@test.local');
    await tester.enterText(find.byKey(const ValueKey('password')), 'secret123');
    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pumpAndSettle();
    expect(find.text('Check your email to confirm your account, then sign in.'), findsOneWidget);
  });
}

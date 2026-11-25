import 'package:material_ui/material_ui.dart';

import '../../shell/tab_shell.dart';
import '../../theme.dart';

/// The native Account tab: sign-in, or the shopper's links into the site.
class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = TabShellScope.of(context);
    final session = scope.services.session;
    final actions = scope.actions;

    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final profile = session.profile;
        final role = profile?.role;
        final rows = <(IconData, String, String)>[
          (Icons.favorite_border, 'Saved pieces', '/wishlist'),
          (Icons.person_outline, 'Edit profile', '/account'),
          // Anyone without a shop yet, including pending or rejected applicants.
          if (role != 'artisan' && role != 'owner') (Icons.storefront_outlined, 'Sell on CraftCebu', '/sell'),
          if (role == 'owner' || profile?.artisanStatus == 'verified') (Icons.inventory_2_outlined, 'Seller Centre', '/seller'),
          if (role == 'owner') (Icons.admin_panel_settings_outlined, 'Admin Centre', '/admin'),
          (Icons.map_outlined, 'Shop by origin', '/origins'),
          (Icons.groups_outlined, 'Meet the makers', '/artisans'),
        ];

        return SafeArea(
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
            children: [
              Text('Account', style: display(32)),
              const SizedBox(height: 20),
              if (!session.signedIn)
                _SignInCard(onTap: actions.requireSignIn)
              else ...[
                Row(children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: atsuete,
                    child: Text(
                      (profile?.fullName.isNotEmpty ?? false) ? profile!.fullName[0].toUpperCase() : '?',
                      style: display(24, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(profile?.fullName.isNotEmpty ?? false ? profile!.fullName : 'CraftCebu shopper', style: display(22)),
                      Text(session.user?.email ?? '', style: body(14, color: muted)),
                    ]),
                  ),
                ]),
                const SizedBox(height: 20),
                Material(
                  color: card,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: line)),
                  clipBehavior: Clip.antiAlias,
                  child: Column(children: [
                    for (final (i, (icon, label, path)) in rows.indexed) ...[
                      if (i > 0) const Divider(height: 1, indent: 56, color: line),
                      ListTile(
                        leading: Icon(icon, color: atsuete),
                        title: Text(label, style: body(15.5, weight: 500)),
                        trailing: const Icon(Icons.chevron_right, color: muted),
                        onTap: () => actions.openWebPage(path),
                      ),
                    ],
                  ]),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () async {
                    await session.signOut();
                    await scope.services.refreshCartCount();
                  },
                  icon: const Icon(Icons.logout),
                  label: const Text('Sign out'),
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50), foregroundColor: ink),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _SignInCard extends StatelessWidget {
  const _SignInCard({required this.onTap});
  final Future<bool> Function() onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(16), border: Border.all(color: line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Sign in or create an account', style: display(22)),
        const SizedBox(height: 6),
        Text('Save pieces, check out and track your orders from Cebuano makers.', style: body(14, color: muted)),
        const SizedBox(height: 16),
        FilledButton(onPressed: onTap, child: const Text('Sign in')),
      ]),
    );
  }
}

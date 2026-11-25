import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
import 'data/cart_repo.dart';
import 'session/app_session.dart';
import 'shell/services.dart';
import 'shell/tab_shell.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // The key is used as-is, so the legacy anon key works here too.
  await Supabase.initialize(url: supabaseUrl, publishableKey: supabaseAnonKey);
  runApp(CraftCebuApp(services: AppServices(session: AppSession(), cart: CartRepo())));
}

class CraftCebuApp extends StatelessWidget {
  const CraftCebuApp({super.key, required this.services});

  final AppServices services;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CraftCebu',
      debugShowCheckedModeBanner: false,
      theme: craftCebuTheme(),
      home: TabShell(services: services),
    );
  }
}

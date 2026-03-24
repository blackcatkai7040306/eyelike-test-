import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide Session;

import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'session.dart';
import 'supabase_config.dart';
import 'theme/eyelike_theme.dart' show buildEyelikeTheme, EyelikeColors;
import 'widgets/optic_mesh_background.dart';

/// Loads env and Supabase. Used from tests without [runApp].
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: 'assets/env');
  final url = dotenv.get('SUPABASE_URL', fallback: '').trim();
  final key = dotenv.get('SUPABASE_ANON_KEY', fallback: '').trim();
  if (url.isNotEmpty && key.isNotEmpty) {
    await Supabase.initialize(url: url, anonKey: key);
    supabaseAppReady = true;
  } else {
    supabaseAppReady = false;
  }
}

Future<void> main() async {
  await bootstrap();
  runApp(const EyelikeApp());
}

class EyelikeApp extends StatefulWidget {
  const EyelikeApp({super.key});

  @override
  State<EyelikeApp> createState() => _EyelikeAppState();
}

class _EyelikeAppState extends State<EyelikeApp> {
  final Session session = Session();
  bool _booting = true;

  @override
  void initState() {
    super.initState();
    session.addListener(_onSession);
    session.load().then((_) {
      if (mounted) setState(() => _booting = false);
    });
  }

  void _onSession() => setState(() {});

  @override
  void dispose() {
    session.removeListener(_onSession);
    session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EyeLike',
      debugShowCheckedModeBanner: false,
      theme: buildEyelikeTheme(),
      home: _booting
          ? const Scaffold(
              body: OpticMeshBackground(
                child: Center(child: CircularProgressIndicator(color: EyelikeColors.cyan)),
              ),
            )
          : session.user == null
              ? AuthScreen(session: session)
              : HomeScreen(session: session),
    );
  }
}

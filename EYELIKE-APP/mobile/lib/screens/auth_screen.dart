import 'package:flutter/material.dart';

import '../session.dart';
import '../supabase_config.dart';
import '../theme/eyelike_theme.dart';
import '../widgets/iris_pulse.dart';
import '../widgets/optic_mesh_background.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.session});

  final Session session;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _email = TextEditingController();
  final _display = TextEditingController();
  final _pass = TextEditingController();
  final _server = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _server.text = widget.session.serverBaseUrl;
  }

  @override
  void dispose() {
    _email.dispose();
    _display.dispose();
    _pass.dispose();
    _server.dispose();
    super.dispose();
  }

  Future<void> _wrap(Future<void> Function() fn) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.session.persistServer(_server.text);
      await fn();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: OpticMeshBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const IrisPulse(size: 72),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('EYELIKE', style: titleEyelike(28)),
                              Text(
                                'Supabase + Socket.IO + WebRTC',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: EyelikeColors.dim,
                                      letterSpacing: 0.4,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (!supabaseAppReady) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Add SUPABASE_URL and SUPABASE_ANON_KEY to assets/env (see comments in that file).',
                        style: TextStyle(color: Theme.of(context).colorScheme.secondary, fontSize: 12),
                      ),
                    ],
                    const SizedBox(height: 28),
                    TextField(
                      controller: _server,
                      decoration: const InputDecoration(
                        labelText: 'Realtime server (Socket.IO)',
                        hintText: 'http://10.0.2.2:3001',
                      ),
                      keyboardType: TextInputType.url,
                      autocorrect: false,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _email,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        hintText: 'you@example.com',
                      ),
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _display,
                      decoration: const InputDecoration(
                        labelText: 'Display name (signup only)',
                        hintText: 'Shown to other users',
                      ),
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _pass,
                      decoration: const InputDecoration(labelText: 'Password'),
                      obscureText: true,
                      onSubmitted: (_) => _busy
                          ? null
                          : _wrap(() => widget.session.login(_email.text, _pass.text)),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        style: TextStyle(color: Theme.of(context).colorScheme.secondary),
                      ),
                    ],
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _busy || !supabaseAppReady
                          ? null
                          : () => _wrap(() => widget.session.login(_email.text, _pass.text)),
                      child: Text(_busy ? '…' : 'Sign in'),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton(
                      onPressed: _busy || !supabaseAppReady
                          ? null
                          : () => _wrap(
                                () => widget.session.register(
                                  _email.text,
                                  _pass.text,
                                  _display.text,
                                ),
                              ),
                      child: const Text('Create account'),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Ensure Supabase has profiles + messages with RLS as you defined. Physical device: use your PC LAN IP for the Socket server.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: EyelikeColors.dim),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

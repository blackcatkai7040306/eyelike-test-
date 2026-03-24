import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../session.dart';
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
  final _user = TextEditingController();
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
    _user.dispose();
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
    } on ApiException catch (e) {
      setState(() => _error = e.message);
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
                                'Test harness · Socket.IO + WebRTC',
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
                    const SizedBox(height: 28),
                    TextField(
                      controller: _server,
                      decoration: const InputDecoration(
                        labelText: 'Server base URL',
                        hintText: 'http://10.0.2.2:3001',
                      ),
                      keyboardType: TextInputType.url,
                      autocorrect: false,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _user,
                      decoration: const InputDecoration(labelText: 'Username'),
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _pass,
                      decoration: const InputDecoration(labelText: 'Password'),
                      obscureText: true,
                      onSubmitted: (_) => _busy ? null : _wrap(() => widget.session.login(_user.text, _pass.text)),
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
                      onPressed: _busy
                          ? null
                          : () => _wrap(() => widget.session.login(_user.text, _pass.text)),
                      child: Text(_busy ? '…' : 'Sign in'),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton(
                      onPressed: _busy
                          ? null
                          : () => _wrap(() => widget.session.register(_user.text, _pass.text)),
                      child: const Text('Create account'),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Physical device: use your PC LAN IP (same Wi‑Fi), not localhost.',
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

import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../session.dart';
import '../theme/eyelike_theme.dart';
import '../widgets/iris_pulse.dart';
import '../widgets/optic_mesh_background.dart';
import 'chat_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.session});

  final Session session;

  @override
  Widget build(BuildContext context) {
    final u = session.user;
    return Scaffold(
      body: OpticMeshBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
                child: Row(
                  children: [
                    const IrisPulse(size: 48),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Peers', style: titleEyelike(22)),
                          Text(
                            'Signed in as ${u?.username ?? "…"}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: EyelikeColors.dim),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Refresh',
                      onPressed: () => session.refreshPeers(),
                      icon: const Icon(Icons.refresh_rounded, color: EyelikeColors.cyan),
                    ),
                    TextButton(
                      onPressed: () => session.logout(),
                      child: const Text('Log out'),
                    ),
                  ],
                ),
              ),
              if (session.connecting)
                const LinearProgressIndicator(minHeight: 2, color: EyelikeColors.cyan),
              if (session.socketError != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Text(
                    'Socket: ${session.socketError}',
                    style: TextStyle(color: Theme.of(context).colorScheme.secondary, fontSize: 12),
                  ),
                ),
              Expanded(
                child: session.peers.isEmpty
                    ? Center(
                        child: Text(
                          'No other users yet.\nOpen a second account in another emulator or device.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: EyelikeColors.dim),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: session.peers.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final p = session.peers[i];
                          return _PeerTile(
                            profile: p,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => ChatScreen(session: session, peer: p),
                                ),
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PeerTile extends StatelessWidget {
  const _PeerTile({required this.profile, required this.onTap});

  final PeerProfile profile;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: EyelikeColors.panel.withValues(alpha: 0.92),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: profile.online ? EyelikeColors.cyan : EyelikeColors.dim,
                  boxShadow: profile.online
                      ? [BoxShadow(color: EyelikeColors.cyan.withValues(alpha: 0.5), blurRadius: 8)]
                      : null,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  profile.username,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                ),
              ),
              Text(
                profile.online ? 'live' : 'away',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: profile.online ? EyelikeColors.cyan : EyelikeColors.dim,
                    ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded, color: EyelikeColors.dim),
            ],
          ),
        ),
      ),
    );
  }
}

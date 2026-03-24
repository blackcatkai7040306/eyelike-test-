class AppUser {
  const AppUser({required this.id, required this.username});

  final String id;
  final String username;

  factory AppUser.fromJson(Map<String, dynamic> j) {
    return AppUser(
      id: j['id'] as String,
      username: j['username'] as String,
    );
  }
}

class PeerProfile {
  const PeerProfile({
    required this.id,
    required this.username,
    required this.online,
  });

  final String id;
  final String username;
  final bool online;

  factory PeerProfile.fromJson(Map<String, dynamic> j) {
    return PeerProfile(
      id: j['id'] as String,
      username: j['username'] as String,
      online: j['online'] as bool? ?? false,
    );
  }
}

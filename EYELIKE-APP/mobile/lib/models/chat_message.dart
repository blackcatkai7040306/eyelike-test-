class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.fromUserId,
    required this.fromUsername,
    required this.text,
    required this.at,
    this.mine = false,
  });

  final String id;
  final String fromUserId;
  final String fromUsername;
  final String text;
  final String at;
  final bool mine;

  factory ChatMessage.fromServer(Map<String, dynamic> j, {required String selfId}) {
    final from = j['fromUserId'] as String;
    return ChatMessage(
      id: j['id'] as String? ?? '${j['at']}-$from',
      fromUserId: from,
      fromUsername: j['fromUsername'] as String? ?? '?',
      text: j['text'] as String? ?? '',
      at: j['at'] as String? ?? '',
      mine: from == selfId,
    );
  }

  /// Row from `public.messages` plus resolved display names.
  factory ChatMessage.fromMessageRow(
    Map<String, dynamic> row, {
    required String selfId,
    required String peerUsername,
    required String myUsername,
  }) {
    final from = row['from_id'] as String;
    final isMine = from == selfId;
    final created = row['created_at'];
    final at = created is String
        ? created
        : (created != null ? created.toString() : '');
    return ChatMessage(
      id: row['id'] as String,
      fromUserId: from,
      fromUsername: isMine ? myUsername : peerUsername,
      text: row['body'] as String? ?? '',
      at: at,
      mine: isMine,
    );
  }
}

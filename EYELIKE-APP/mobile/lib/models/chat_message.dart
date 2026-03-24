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
}

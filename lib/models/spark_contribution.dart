class SparkContribution {
  const SparkContribution({
    required this.id,
    required this.groupId,
    required this.turnVersion,
    required this.senderId,
    required this.recipientId,
    required this.senderName,
    required this.recipientName,
    required this.promptId,
    required this.prompt,
    required this.answer,
    required this.createdAt,
  });
  final String id;
  final String groupId;
  final int turnVersion;
  final String senderId;
  final String recipientId;
  final String senderName;
  final String recipientName;
  final String promptId;
  final String prompt;
  final String answer;
  final DateTime createdAt;
  factory SparkContribution.fromJson(Map<String, dynamic> value) =>
      SparkContribution(
        id: value['id'] as String,
        groupId: value['group_id'] as String,
        turnVersion: (value['turn_version'] as num).toInt(),
        senderId: value['sender_id'] as String,
        recipientId: value['recipient_id'] as String,
        senderName: value['sender_name'] as String,
        recipientName: value['recipient_name'] as String,
        promptId: value['prompt_id'] as String,
        prompt: value['prompt_text'] as String,
        answer: value['answer'] as String,
        createdAt: DateTime.parse(value['created_at'] as String),
      );
}

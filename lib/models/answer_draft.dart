class DraftKey {
  const DraftKey({
    required this.userId,
    required this.groupId,
    required this.promptId,
  });
  final String userId;
  final String groupId;
  final String promptId;

  List<String> get parts => [userId, groupId, promptId];
}

class AnswerDraft {
  const AnswerDraft({
    required this.key,
    required this.prompt,
    required this.text,
    required this.savedAt,
  });
  final DraftKey key;
  final String prompt;
  final String text;
  final DateTime savedAt;

  Map<String, Object> toJson() => {
    'schemaVersion': 1,
    'userId': key.userId,
    'groupId': key.groupId,
    'promptId': key.promptId,
    'prompt': prompt,
    'text': text,
    'savedAt': savedAt.toUtc().toIso8601String(),
  };

  factory AnswerDraft.fromJson(Map<String, dynamic> json) {
    if (json['schemaVersion'] != 1) {
      throw const FormatException('Unsupported draft format');
    }
    return AnswerDraft(
      key: DraftKey(
        userId: json['userId'] as String,
        groupId: json['groupId'] as String,
        promptId: json['promptId'] as String,
      ),
      prompt: json['prompt'] as String,
      text: json['text'] as String,
      savedAt: DateTime.parse(json['savedAt'] as String),
    );
  }
}

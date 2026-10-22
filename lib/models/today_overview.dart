class SparkGroup {
  const SparkGroup({
    required this.id,
    required this.name,
    required this.memberCount,
    required this.holderId,
    required this.holderName,
    required this.promptId,
    required this.prompt,
    this.version = 1,
  });

  final String id;
  final String name;
  final int memberCount;
  final String holderId;
  final String holderName;
  final String promptId;
  final String prompt;
  final int version;
}

class SparkActivity {
  const SparkActivity({
    required this.title,
    required this.groupName,
    required this.when,
    required this.detail,
  });

  final String title;
  final String groupName;
  final String when;
  final String detail;
}

class TodayOverview {
  const TodayOverview({
    required this.viewerId,
    required this.groups,
    required this.activities,
  });

  final String viewerId;
  final List<SparkGroup> groups;
  final List<SparkActivity> activities;

  List<SparkGroup> get yourTurns => groups
      .where((group) => group.holderId == viewerId)
      .toList(growable: false);
}

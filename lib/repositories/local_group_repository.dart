import 'dart:math';
import 'package:characters/characters.dart';
import 'package:flutter/foundation.dart';

import '../models/group_details.dart';
import '../models/spark_contribution.dart';
import '../models/today_overview.dart';
import 'demo_today_repository.dart';
import 'group_repository.dart';

/// Session-only development data. This is not shared membership or authorisation.
class LocalGroupRepository extends ChangeNotifier implements GroupRepository {
  LocalGroupRepository({bool seedDemo = true}) {
    if (seedDemo) {
      final names = [
        ['Misael', 'Sam', 'Alex', 'Noor'],
        ['Misael', 'Jamie', 'Robin', 'Dani', 'Luca'],
      ];
      for (var i = 0; i < DemoTodayRepository.overview.groups.length; i++) {
        final group = DemoTodayRepository.overview.groups[i];
        _groups[group.id] = GroupDetails(
          group: group,
          viewerId: viewerId,
          members: [
            for (var j = 0; j < names[i].length; j++)
              GroupMember(
                id: j == 0 ? viewerId : '${group.id}-member-$j',
                name: names[i][j],
                isOrganiser: j == 0,
              ),
          ],
        );
      }
    }
  }

  @override
  bool get isLocalPreview => true;
  @override
  Future<List<GroupMembershipRequest>> loadMembershipRequests(
    String groupId,
  ) async => const [];
  @override
  Future<void> approveMembershipRequest(String requestId) async {
    throw const GroupInputException(
      'Approvals are available in connected groups.',
    );
  }

  @override
  Future<void> leaveGroup(String groupId) async {
    final details = _groups[groupId];
    if (details == null) return;
    if (details.isViewerOrganiser || details.group.holderId == viewerId) {
      throw const GroupInputException(
        'A handover is needed before you can leave.',
      );
    }
    _groups.remove(groupId);
    _requests.remove(groupId);
    notifyListeners();
  }

  @override
  Future<void> inviteMember(String groupId, String email) async {
    throw const GroupInputException(
      'Invitations are available in connected groups.',
    );
  }

  @override
  Future<void> respondToInvitation(
    String invitationId, {
    required bool accept,
  }) async {
    throw const GroupInputException(
      'Invitations are available in connected groups.',
    );
  }

  @override
  Future<List<SparkContribution>> loadContributions(String groupId) async {
    await loadGroup(groupId);
    return List.unmodifiable(
      _contributions
          .where((c) => c.groupId == groupId)
          .toList()
          .reversed
          .take(100),
    );
  }

  @override
  Future<SparkContribution> passSpark({
    required SparkGroup turn,
    required String recipientId,
    required String answer,
  }) async {
    final details = await loadGroup(turn.id);
    final clean = answer.trim();
    if (clean.isEmpty || answer.characters.length > 300) {
      throw const GroupInputException(
        'Write an answer of up to 300 characters.',
      );
    }
    for (final saved in _contributions) {
      if (saved.groupId == turn.id && saved.turnVersion == turn.version) {
        if (saved.senderId == viewerId &&
            saved.recipientId == recipientId &&
            saved.answer == clean &&
            saved.promptId == turn.promptId) {
          return saved;
        }
        throw const GroupInputException('This turn has already been passed.');
      }
    }
    if (details.group.holderId != viewerId ||
        details.group.version != turn.version ||
        details.group.promptId != turn.promptId) {
      throw const GroupInputException(
        'Your turn has changed. Refresh the group.',
      );
    }
    final recipients = details.members.where(
      (m) => m.id == recipientId && m.id != viewerId,
    );
    if (recipients.isEmpty) {
      throw const GroupInputException('Choose another group member.');
    }
    final recipient = recipients.first;
    final saved = SparkContribution(
      id: 'local-${turn.id}-${turn.version}',
      groupId: turn.id,
      turnVersion: turn.version,
      senderId: viewerId,
      recipientId: recipientId,
      senderName: details.group.holderName,
      recipientName: recipient.name,
      promptId: turn.promptId,
      prompt: turn.prompt,
      answer: clean,
      createdAt: DateTime.now(),
    );
    _contributions.add(saved);
    final g = details.group;
    _groups[g.id] = GroupDetails(
      group: SparkGroup(
        id: g.id,
        name: g.name,
        memberCount: g.memberCount,
        holderId: recipientId,
        holderName: recipient.name,
        promptId: '${g.promptId}-turn-${g.version + 1}',
        prompt: g.prompt,
        version: g.version + 1,
      ),
      viewerId: details.viewerId,
      inviteCode: details.inviteCode,
      members: details.members,
    );
    notifyListeners();
    return saved;
  }

  static const viewerId = 'preview-student';
  static const sampleInviteCode = 'STUDY26';
  final Map<String, GroupDetails> _groups = {};
  final Map<String, GroupJoinRequest> _requests = {};
  final _random = Random.secure();
  final List<SparkContribution> _contributions = [];

  @override
  Future<TodayOverview> loadToday() async => TodayOverview(
    viewerId: viewerId,
    groups: List.unmodifiable(_groups.values.map((d) => d.group)),
    activities: _contributions.isNotEmpty
        ? _contributions.reversed
              .take(10)
              .where((c) => _groups.containsKey(c.groupId))
              .map(
                (c) => SparkActivity(
                  title:
                      '${c.senderName} passed the spark to ${c.recipientName}',
                  groupName: _groups[c.groupId]!.group.name,
                  when: c.createdAt.toLocal().toString().substring(0, 16),
                  detail: 'Answer shared with the group.',
                ),
              )
              .toList()
        : _groups.containsKey('mobile-dev')
        ? DemoTodayRepository.overview.activities
        : const [],
  );

  @override
  Future<GroupOverview> loadGroups() async => GroupOverview(
    viewerId: viewerId,
    groups: _groups.values.map((d) => d.group).toList(),
    requests: _requests.values.toList(),
  );

  @override
  Future<GroupDetails> loadGroup(String groupId) async {
    final details = _groups[groupId];
    if (details == null || !details.members.any((m) => m.id == viewerId)) {
      throw const GroupInputException('This group is not available to you.');
    }
    return details;
  }

  @override
  Future<GroupDetails> createGroup(String name) async {
    final clean = name.trim();
    final error = validateGroupName(clean);
    if (error != null) throw GroupInputException(error);
    if (clean.characters.length > 60) {
      throw const GroupInputException('Use 60 characters or fewer.');
    }
    // One local operation creates the group, its organiser and first holder.
    final id =
        'local-group-${List.generate(16, (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0')).join()}';
    final details = GroupDetails(
      viewerId: viewerId,
      group: SparkGroup(
        id: id,
        name: clean,
        memberCount: 1,
        holderId: viewerId,
        holderName: 'Misael',
        promptId: 'first-connection',
        prompt: 'What helped your group connect this week?',
      ),
      members: const [
        GroupMember(id: viewerId, name: 'Misael', isOrganiser: true),
      ],
    );
    _groups[id] = details;
    notifyListeners();
    return details;
  }

  @override
  Future<GroupJoinRequest> requestToJoin(String code) async {
    final error = validateInviteCode(code);
    if (error != null) throw GroupInputException(error);
    if (code.trim().toUpperCase() != sampleInviteCode) {
      throw const GroupInputException(
        'This code was not found. Check it and try again.',
      );
    }
    if (_groups.containsKey('study-circle')) {
      throw const GroupInputException('You already belong to this group.');
    }
    final existing = _requests['study-circle'];
    if (existing != null) return existing;
    const request = GroupJoinRequest(
      groupId: 'study-circle',
      groupName: 'Study Circle',
    );
    _requests[request.groupId] = request;
    notifyListeners();
    return request;
  }
}

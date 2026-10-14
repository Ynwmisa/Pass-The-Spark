import 'dart:math';
import 'package:characters/characters.dart';
import 'package:flutter/foundation.dart';

import '../models/group_details.dart';
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

  static const viewerId = 'preview-student';
  static const sampleInviteCode = 'STUDY26';
  final Map<String, GroupDetails> _groups = {};
  final Map<String, GroupJoinRequest> _requests = {};
  final _random = Random.secure();

  @override
  Future<TodayOverview> loadToday() async => TodayOverview(
    viewerId: viewerId,
    groups: List.unmodifiable(_groups.values.map((d) => d.group)),
    activities: _groups.containsKey('mobile-dev')
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

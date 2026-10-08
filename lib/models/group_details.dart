import 'today_overview.dart';

class GroupMember {
  const GroupMember({
    required this.id,
    required this.name,
    this.isOrganiser = false,
  });
  final String id;
  final String name;
  final bool isOrganiser;
}

class GroupDetails {
  GroupDetails({
    required this.group,
    required this.viewerId,
    this.inviteCode,
    required List<GroupMember> members,
  }) : members = List.unmodifiable(members);
  final SparkGroup group;
  final String viewerId;
  final List<GroupMember> members;
  final String? inviteCode;
}

/// A request contains only the public invitation label, never private content.
class GroupJoinRequest {
  const GroupJoinRequest({required this.groupId, required this.groupName});
  final String groupId;
  final String groupName;
}

class GroupOverview {
  GroupOverview({
    required this.viewerId,
    required List<SparkGroup> groups,
    required List<GroupJoinRequest> requests,
  }) : groups = List.unmodifiable(groups),
       requests = List.unmodifiable(requests);
  final String viewerId;
  final List<SparkGroup> groups;
  final List<GroupJoinRequest> requests;
}

class GroupInputException implements Exception {
  const GroupInputException(this.message);
  final String message;
}

String? validateGroupName(String? value) {
  final name = (value ?? '').trim();
  if (name.isEmpty) return 'Enter a group name.';
  if (name.runes.any((r) => r < 32 || r == 127)) {
    return 'Use a name without line breaks or control characters.';
  }
  return null;
}

String? validateInviteCode(String? value) {
  final code = (value ?? '').trim();
  if (!RegExp(r'^[a-zA-Z0-9]{6,12}$').hasMatch(code)) {
    return 'Enter the 6–12 letter or number code.';
  }
  return null;
}

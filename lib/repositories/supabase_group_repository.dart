import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/group_details.dart';
import '../models/today_overview.dart';
import 'group_repository.dart';

class SupabaseGroupRepository extends ChangeNotifier
    implements GroupRepository {
  SupabaseGroupRepository(this.client)
    : _viewerId = client.auth.currentUser!.id;
  final SupabaseClient client;
  final String _viewerId;
  final Map<String, String> _createRequests = {};
  final Map<String, String> _invitationRequests = {};
  bool _disposed = false;
  @override
  bool get isLocalPreview => false;

  void _checkAccount() {
    if (_disposed || client.auth.currentUser?.id != _viewerId) {
      throw const GroupInputException('Your session changed. Sign in again.');
    }
  }

  Future<T> _call<T>(Future<T> Function() operation) async {
    _checkAccount();
    try {
      final result = await operation();
      _checkAccount();
      return result;
    } on PostgrestException catch (e) {
      if (e.code == '22023' || e.code == '42501') {
        throw GroupInputException(e.message);
      }
      throw const GroupInputException(
        'Could not load or save group information. Please try again.',
      );
    }
  }

  @override
  Future<GroupOverview> loadGroups() => _call(() async {
    final raw = Map<String, dynamic>.from(
      await client.rpc('my_group_overview') as Map,
    );
    return GroupOverview(
      viewerId: raw['viewer_id'] as String,
      invitations: ((raw['invitations'] as List?) ?? []).map((v) {
        final item = Map<String, dynamic>.from(v as Map);
        return GroupInvitation(
          id: item['id'] as String,
          groupId: item['group_id'] as String,
          groupName: item['group_name'] as String,
        );
      }).toList(),
      groups: (raw['groups'] as List)
          .map((v) => _group(Map<String, dynamic>.from(v as Map)))
          .toList(),
      requests: (raw['requests'] as List)
          .map((v) => _request(Map<String, dynamic>.from(v as Map)))
          .toList(),
    );
  });
  @override
  Future<TodayOverview> loadToday() async {
    final overview = await loadGroups();
    return TodayOverview(
      viewerId: overview.viewerId,
      groups: overview.groups,
      activities: const [],
    );
  }

  @override
  Future<GroupDetails> loadGroup(String groupId) => _call(() async {
    final raw = Map<String, dynamic>.from(
      await client.rpc('group_context', params: {'p_group_id': groupId}) as Map,
    );
    return GroupDetails(
      viewerId: raw['viewer_id'] as String,
      group: _group(Map<String, dynamic>.from(raw['group'] as Map)),
      inviteCode: raw['invite_code'] as String?,
      members: (raw['members'] as List).map((v) {
        final m = Map<String, dynamic>.from(v as Map);
        return GroupMember(
          id: m['id'] as String,
          name: m['name'] as String,
          isOrganiser: m['is_organiser'] as bool,
        );
      }).toList(),
    );
  });
  @override
  Future<GroupDetails> createGroup(String name) => _call(() async {
    final clean = name.trim();
    final error = validateGroupName(clean);
    if (error != null) throw GroupInputException(error);
    // Keep the same ID after a lost response, so retry does not create a second group.
    final requestId = _createRequests.putIfAbsent(clean, _requestId);
    final id =
        await client.rpc(
              'create_group',
              params: {'p_name': clean, 'p_request_id': requestId},
            )
            as String;
    final details = await loadGroup(id);
    _createRequests.remove(clean);
    if (!_disposed) notifyListeners();
    return details;
  });
  @override
  Future<GroupJoinRequest> requestToJoin(String code) => _call(() async {
    final error = validateInviteCode(code);
    if (error != null) throw GroupInputException(error);
    final raw = Map<String, dynamic>.from(
      await client.rpc(
            'request_to_join',
            params: {'p_code': code.trim().toUpperCase()},
          )
          as Map,
    );
    if (!_disposed) notifyListeners();
    return _request(raw);
  });

  @override
  Future<List<GroupMembershipRequest>> loadMembershipRequests(String groupId) =>
      _call(() async {
        final rows =
            await client.rpc(
                  'list_group_requests',
                  params: {'p_group_id': groupId},
                )
                as List;
        return List.unmodifiable(
          rows.map((row) {
            final item = Map<String, dynamic>.from(row as Map);
            return GroupMembershipRequest(
              id: item['id'] as String,
              displayName: item['display_name'] as String,
            );
          }),
        );
      });
  @override
  Future<void> approveMembershipRequest(String requestId) => _call(() async {
    await client.rpc(
      'approve_join_request',
      params: {'p_request_id': requestId},
    );
    _checkAccount();
    notifyListeners();
  });

  @override
  Future<void> leaveGroup(String groupId) => _call(() async {
    await client.rpc('leave_group', params: {'p_group_id': groupId});
    _checkAccount();
    notifyListeners();
  });

  @override
  Future<void> inviteMember(String groupId, String email) => _call(() async {
    final error = validateInvitationEmail(email);
    if (error != null) throw GroupInputException(error);
    final clean = email.trim().toLowerCase();
    final key = '$groupId:$clean';
    final request = _invitationRequests.putIfAbsent(key, _requestId);
    await client.rpc(
      'invite_group_member',
      params: {
        'p_group_id': groupId,
        'p_email': clean,
        'p_request_id': request,
      },
    );
    _checkAccount();
    _invitationRequests.remove(key);
    notifyListeners();
  });
  @override
  Future<void> respondToInvitation(
    String invitationId, {
    required bool accept,
  }) => _call(() async {
    await client.rpc(
      'respond_to_group_invitation',
      params: {'p_invitation_id': invitationId, 'p_accept': accept},
    );
    _checkAccount();
    notifyListeners();
  });

  static SparkGroup _group(Map<String, dynamic> m) => SparkGroup(
    id: m['id'] as String,
    name: m['name'] as String,
    memberCount: (m['member_count'] as num).toInt(),
    holderId: m['holder_id'] as String,
    holderName: m['holder_name'] as String,
    promptId: m['prompt_id'] as String,
    prompt: m['prompt'] as String,
  );
  static GroupJoinRequest _request(Map<String, dynamic> m) => GroupJoinRequest(
    groupId: m['group_id'] as String,
    groupName: m['group_name'] as String,
  );
  static String _requestId() {
    final r = Random.secure();
    final b = List.generate(16, (_) => r.nextInt(256));
    b[6] = (b[6] & 15) | 64;
    b[8] = (b[8] & 63) | 128;
    final h = b.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

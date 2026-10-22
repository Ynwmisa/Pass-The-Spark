import 'package:flutter/foundation.dart';
import '../models/group_details.dart';
import '../models/spark_contribution.dart';
import '../models/today_overview.dart';
import 'today_repository.dart';

abstract interface class GroupRepository
    implements TodayRepository, Listenable {
  bool get isLocalPreview;
  Future<GroupOverview> loadGroups();
  Future<GroupDetails> loadGroup(String groupId);
  Future<GroupDetails> createGroup(String name);
  Future<GroupJoinRequest> requestToJoin(String code);
  Future<List<GroupMembershipRequest>> loadMembershipRequests(String groupId);
  Future<void> inviteMember(String groupId, String email);
  Future<void> respondToInvitation(String invitationId, {required bool accept});
  Future<SparkContribution> passSpark({
    required SparkGroup turn,
    required String recipientId,
    required String answer,
  });
  Future<List<SparkContribution>> loadContributions(String groupId);
  Future<void> leaveGroup(String groupId);
  Future<void> approveMembershipRequest(String requestId);
}

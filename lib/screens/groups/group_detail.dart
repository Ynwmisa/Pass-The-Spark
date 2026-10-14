import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/group_details.dart';
import '../../repositories/group_repository.dart';
import '../../theme/app_colors.dart';
import '../../widgets/group_data_view.dart';
import '../../widgets/local_groups_notice.dart';
import 'leave_group.dart';

class GroupDetailScreen extends StatelessWidget {
  const GroupDetailScreen({
    super.key,
    required this.repository,
    required this.groupId,
  });
  final GroupRepository repository;
  final String groupId;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Group'),
      backgroundColor: Colors.transparent,
    ),
    body: GroupDataView<GroupDetails>(
      key: ValueKey(groupId),
      repository: repository,
      load: () => repository.loadGroup(groupId),
      errorMessage: 'This group is unavailable. Return to Groups or try again.',
      builder: (context, details, refresh) => RefreshIndicator(
        onRefresh: refresh,
        child: ListView(
          padding: const EdgeInsets.all(24),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Text(
              details.group.name,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Private circle · ${details.members.length} ${details.members.length == 1 ? 'member' : 'members'}',
            ),
            const SizedBox(height: 16),
            if (repository.isLocalPreview) const LocalGroupsNotice(),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.mint,
                borderRadius: BorderRadius.circular(19),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.auto_awesome_outlined,
                    color: AppColors.darkTeal,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    details.group.holderId == details.viewerId
                        ? 'You hold the spark'
                        : '${details.group.holderName} holds the spark',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    details.group.prompt,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 16),
                  if (details.group.holderId == details.viewerId)
                    FilledButton(
                      onPressed: () => context.push('/answer/$groupId'),
                      child: const Text('Answer prompt'),
                    )
                  else
                    const Text(
                      'It is their turn. Your prompt will appear when the spark reaches you.',
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              onPressed: () => context.push('/groups/$groupId/members'),
              icon: const Icon(Icons.people_outline),
              label: const Text('Members and requests'),
            ),
            if (details.inviteCode != null) ...[
              const SizedBox(height: 20),
              const Text('Invite code · expires after 7 days'),
              SelectableText(details.inviteCode!),
            ],
            const SizedBox(height: 24),
            Semantics(
              header: true,
              child: Text(
                'Members',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 12),
            for (final member in details.members)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        member.id == details.viewerId
                            ? '${member.name} (you)'
                            : member.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [
                          if (member.isOrganiser) 'Organiser' else 'Member',
                          if (member.id == details.group.holderId)
                            'Current spark holder',
                        ].join(' · '),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),
            const Text('Shared answers will be added in a later feature.'),
            const SizedBox(height: 24),
            LeaveGroupAction(repository: repository, details: details),
          ],
        ),
      ),
    ),
  );
}

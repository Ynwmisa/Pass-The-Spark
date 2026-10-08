import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/group_details.dart';
import '../../repositories/group_repository.dart';
import '../../theme/app_colors.dart';
import '../../widgets/group_card.dart';
import '../../widgets/group_data_view.dart';
import '../../widgets/local_groups_notice.dart';

class GroupsScreen extends StatelessWidget {
  const GroupsScreen({super.key, required this.repository});
  final GroupRepository repository;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Groups'),
      backgroundColor: Colors.transparent,
    ),
    body: GroupDataView<GroupOverview>(
      repository: repository,
      load: repository.loadGroups,
      builder: (context, overview, refresh) => RefreshIndicator(
        onRefresh: refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Your circles',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            const Text('A little connection, one spark at a time.'),
            const SizedBox(height: 16),
            const LocalGroupsNotice(),
            FilledButton.icon(
              onPressed: () => context.push('/groups/create'),
              icon: const Icon(Icons.add),
              label: const Text('Create group'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              onPressed: () => context.push('/groups/join'),
              icon: const Icon(Icons.group_add_outlined),
              label: const Text('Join with a code'),
            ),
            const SizedBox(height: 24),
            if (overview.groups.isEmpty)
              const Text(
                'No groups yet. Create a circle or request to join one.',
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns =
                      constraints.maxWidth >= 340 &&
                          MediaQuery.textScalerOf(context).scale(14) <= 21
                      ? 2
                      : 1;
                  final width =
                      (constraints.maxWidth - (columns - 1) * 16) / columns;
                  return Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      for (final group in overview.groups)
                        SizedBox(
                          width: width,
                          child: GroupCard(
                            group: group,
                            isYourTurn: group.holderId == overview.viewerId,
                            highlighted: group.holderId == overview.viewerId,
                            onTap: () => context.push('/groups/${group.id}'),
                          ),
                        ),
                    ],
                  );
                },
              ),
            if (overview.requests.isNotEmpty) ...[
              const SizedBox(height: 24),
              Semantics(
                header: true,
                child: Text(
                  'Join requests',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const SizedBox(height: 12),
              for (final request in overview.requests)
                Card(
                  color: AppColors.mint,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          request.groupName,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Pending in this preview. You are not a member yet.',
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    ),
  );
}

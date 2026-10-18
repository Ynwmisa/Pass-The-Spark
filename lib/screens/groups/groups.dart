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
    body: SafeArea(
      child: GroupDataView<GroupOverview>(
        repository: repository,
        load: repository.loadGroups,
        builder: (context, overview, refresh) => RefreshIndicator(
          onRefresh: refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                'Your groups',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              const Text('See your groups and manage membership.'),
              const SizedBox(height: 16),
              if (repository.isLocalPreview) const LocalGroupsNotice(),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: 12,
                runSpacing: 8,
                children: [
                  _CountBadge(
                    '${overview.groups.length} ${overview.groups.length == 1 ? 'group' : 'groups'}',
                  ),
                  _CountBadge(
                    '${overview.requests.length} pending ${overview.requests.length == 1 ? 'request' : 'requests'}',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final create = FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.teal,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                    ),
                    onPressed: () => context.push('/groups/create'),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Create group'),
                  );
                  final join = OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.navy,
                      side: const BorderSide(color: AppColors.border),
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                    ),
                    onPressed: () => context.push('/groups/join'),
                    child: const Text('Join group'),
                  );
                  if (constraints.maxWidth < 280 ||
                      MediaQuery.textScalerOf(context).scale(14) > 21) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [create, const SizedBox(height: 12), join],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: create),
                      const SizedBox(width: 12),
                      Expanded(child: join),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
              Semantics(
                header: true,
                child: Text(
                  'My groups',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const SizedBox(height: 12),
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
              const SizedBox(height: 24),
              Semantics(
                header: true,
                child: Text(
                  'Invitations',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'No invitations yet',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Have an invite code? Use Join group to request access.',
                      style: TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
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
                          Text(
                            repository.isLocalPreview
                                ? 'Pending in this preview. You are not a member yet.'
                                : 'Waiting for organiser approval. You are not a member yet.',
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
    ),
  );
}

class _CountBadge extends StatelessWidget {
  const _CountBadge(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: BoxDecoration(
      color: AppColors.mint,
      borderRadius: BorderRadius.circular(24),
    ),
    child: Text(
      label,
      style: const TextStyle(
        color: AppColors.darkTeal,
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

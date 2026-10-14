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

  void _timeline(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => const SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 8, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Group timeline',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 12),
            Text(
              'No contributions to show yet. Shared answers will appear here when spark passing is available.',
            ),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: GroupDataView<GroupDetails>(
        key: ValueKey(groupId),
        repository: repository,
        load: () => repository.loadGroup(groupId),
        errorMessage:
            'This group is unavailable. Return to Groups or try again.',
        builder: (context, details, refresh) {
          final ownSpark = details.group.holderId == details.viewerId;
          return RefreshIndicator(
            onRefresh: refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Back',
                      onPressed: () {
                        if (context.canPop()) {
                          context.pop();
                        } else {
                          context.go('/groups');
                        }
                      },
                      icon: const Icon(Icons.chevron_left),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 40,
                        minHeight: 48,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        details.group.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.mint,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Text(
                        '${details.members.length} ${details.members.length == 1 ? 'MEMBER' : 'MEMBERS'}',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppColors.darkTeal,
                        ),
                      ),
                    ),
                  ],
                ),
                if (repository.isLocalPreview) const LocalGroupsNotice(),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.navy,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        ownSpark ? 'CURRENT SPARK' : 'CURRENT HOLDER',
                        style: const TextStyle(
                          color: Color(0xFFD6E4E9),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: .5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        ownSpark
                            ? 'You have the spark'
                            : '${details.group.holderName} holds the spark',
                        style: Theme.of(
                          context,
                        ).textTheme.titleLarge?.copyWith(color: Colors.white),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        ownSpark
                            ? details.group.prompt
                            : 'You’ll be able to answer a prompt when it reaches you.',
                        style: const TextStyle(
                          color: Color(0xFFD6E4E9),
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 18),
                      if (ownSpark)
                        FilledButton(
                          onPressed: () => context.push('/answer/$groupId'),
                          child: const Text('Answer prompt →'),
                        )
                      else
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.amber,
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: const Text(
                              'WAITING FOR YOUR TURN',
                              style: TextStyle(
                                color: AppColors.navy,
                                fontWeight: FontWeight.w800,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _heading(context, 'Group overview'),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final tiles = [
                      _OverviewTile(
                        title: 'Members',
                        subtitle:
                            '${details.members.length} ${details.members.length == 1 ? 'person' : 'people'}',
                        color: AppColors.mint,
                        onTap: () => context.push('/groups/$groupId/members'),
                      ),
                      _OverviewTile(
                        title: 'Timeline',
                        subtitle: 'Read contributions',
                        color: Colors.white,
                        onTap: () => _timeline(context),
                      ),
                    ];
                    if (MediaQuery.textScalerOf(context).scale(14) > 23 ||
                        constraints.maxWidth < 260) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          tiles[0],
                          const SizedBox(height: 12),
                          tiles[1],
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: tiles[0]),
                        const SizedBox(width: 12),
                        Expanded(child: tiles[1]),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 20),
                _heading(context, 'Recent contributions'),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'No contributions yet',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Shared answers will appear here when spark passing is available.',
                        style: TextStyle(color: AppColors.muted, height: 1.5),
                      ),
                    ],
                  ),
                ),
                if (details.inviteCode != null) ...[
                  const SizedBox(height: 16),
                  TextButton.icon(
                    onPressed: () => showModalBottomSheet<void>(
                      context: context,
                      showDragHandle: true,
                      builder: (_) => SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Share invite code',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 12),
                              SelectableText(
                                details.inviteCode!,
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineSmall,
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Codes expire 7 days after creation. New members need your approval before they can access the group.',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.share_outlined),
                    label: const Text('Share invite code'),
                  ),
                ],
                const SizedBox(height: 24),
                LeaveGroupAction(repository: repository, details: details),
              ],
            ),
          );
        },
      ),
    ),
  );
  Widget _heading(BuildContext context, String text) => Semantics(
    header: true,
    child: Text(text, style: Theme.of(context).textTheme.titleMedium),
  );
}

class _OverviewTile extends StatelessWidget {
  const _OverviewTile({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: color,
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

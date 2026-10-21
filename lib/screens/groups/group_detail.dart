import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../models/group_details.dart';
import '../../repositories/group_repository.dart';
import '../../theme/app_colors.dart';
import '../../widgets/group_data_view.dart';
import '../../widgets/local_groups_notice.dart';
import 'leave_group.dart';
import 'invite_member.dart';

class GroupDetailScreen extends StatelessWidget {
  const GroupDetailScreen({
    super.key,
    required this.repository,
    required this.groupId,
  });
  final GroupRepository repository;
  final String groupId;

  void _open(BuildContext context, Widget screen) => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => screen));

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
                        '${details.group.name} — group page',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                if (repository.isLocalPreview) const LocalGroupsNotice(),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.navy,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                            ? 'You hold the spark'
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
                      if (ownSpark) ...[
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: () => context.push('/answer/$groupId'),
                            child: const Text('Answer prompt →'),
                          ),
                        ),
                      ],
                      if (!ownSpark) ...[
                        const SizedBox(height: 16),
                        Container(
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
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Semantics(
                  header: true,
                  child: Text(
                    'Group tools',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const SizedBox(height: 12),
                _ToolRow(
                  title: 'Members & invitations',
                  subtitle: '${details.members.length} joined',
                  onTap: () => context.push('/groups/$groupId/members'),
                ),
                const SizedBox(height: 12),
                _ToolRow(
                  title: 'Shared timeline',
                  subtitle: 'Previous answers and passes',
                  onTap: () => _open(
                    context,
                    Scaffold(
                      appBar: AppBar(title: const Text('Group timeline')),
                      body: const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'No contributions to show yet. Shared answers will appear here when spark passing is available.',
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _ToolRow(
                  title: 'Group settings',
                  subtitle: 'Name and invitation options',
                  onTap: () => _open(
                    context,
                    _GroupSettings(repository: repository, details: details),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ),
  );
}

class _ToolRow extends StatelessWidget {
  const _ToolRow({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(14),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
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
            const SizedBox(width: 12),
            const Icon(Icons.chevron_right, size: 18, color: AppColors.muted),
          ],
        ),
      ),
    ),
  );
}

class _GroupSettings extends StatelessWidget {
  const _GroupSettings({required this.repository, required this.details});
  final GroupRepository repository;
  final GroupDetails details;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Group settings')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Group name', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(details.group.name),
        const SizedBox(height: 24),
        if (details.isViewerOrganiser && !repository.isLocalPreview) ...[
          _ToolRow(
            title: 'Invite member',
            subtitle: 'Send an in-app invitation by email',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => InviteMemberScreen(
                  repository: repository,
                  groupId: details.group.id,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (details.inviteCode != null)
          _ToolRow(
            title: 'Share invite code',
            subtitle: 'Allow classmates to request access',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => _ShareInviteCode(details: details),
              ),
            ),
          ),
        const SizedBox(height: 24),
        LeaveGroupAction(repository: repository, details: details),
      ],
    ),
  );
}

class _ShareInviteCode extends StatelessWidget {
  const _ShareInviteCode({required this.details});
  final GroupDetails details;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Share invite code')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text('Invite classmates using a code.'),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.mint,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                details.group.name.toUpperCase(),
                style: Theme.of(context).textTheme.labelSmall,
              ),
              const SizedBox(height: 24),
              SelectableText(
                details.inviteCode!,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              const Text('Expires 7 days after creation.'),
            ],
          ),
        ),
        const SizedBox(height: 24),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.navy,
            foregroundColor: Colors.white,
          ),
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: details.inviteCode!));
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Invite code copied')),
              );
            }
          },
          child: const Text('Copy invite code'),
        ),
        const SizedBox(height: 16),
        const Text(
          'Only share this code with students you trust. New members need organiser approval before they can access the group.',
        ),
      ],
    ),
  );
}

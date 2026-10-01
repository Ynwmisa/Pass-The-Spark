import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/today_overview.dart';
import '../repositories/today_repository.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/activity_card.dart';
import '../widgets/group_card.dart';
import '../widgets/prompt_card.dart';

class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key, required this.repository});
  final TodayRepository repository;

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  late Future<TodayOverview> _overview;
  int _promptIndex = 0;

  @override
  void initState() {
    super.initState();
    _overview = widget.repository.loadToday();
  }

  Future<void> _refresh() async {
    final next = widget.repository.loadToday();
    setState(() {
      _overview = next;
      _promptIndex = 0;
    });
    // FutureBuilder displays repository errors and offers an explicit retry.
    try {
      await next;
    } catch (_) {
      // The error is handled by the snapshot below.
    }
  }

  void _showPrompt(SparkGroup group) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(group.name, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 16),
              Text(group.prompt, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              const Text(
                'Answering and passing are coming next. '
                'Your spark stays with you for now.',
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Back to Today'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    bottom: false,
    child: FutureBuilder<TodayOverview>(
      future: _overview,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Your groups could not be loaded.'),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _refresh,
                    child: const Text('Try again'),
                  ),
                ],
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(
              semanticsLabel: 'Loading your groups',
            ),
          );
        }
        final overview = snapshot.requireData;
        final turns = overview.yourTurns;
        final index = turns.isEmpty
            ? 0
            : _promptIndex.clamp(0, turns.length - 1);
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 19, 24, 24),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              Text(
                'Good afternoon!',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 6),
              const Text('Here’s what’s happening in your circles.'),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(child: _heading(context, 'Your turn')),
                  if (turns.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.mint,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        '${turns.length} ${turns.length == 1 ? 'prompt' : 'prompts'}',
                        style: const TextStyle(
                          color: AppColors.darkTeal,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (turns.isEmpty)
                const _CaughtUpCard()
              else ...[
                PromptCard(
                  group: turns[index],
                  onAnswer: () => _showPrompt(turns[index]),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _pageButton(
                      label: 'Previous prompt',
                      icon: Icons.chevron_left,
                      onPressed: index > 0
                          ? () => setState(() => _promptIndex = index - 1)
                          : null,
                    ),
                    Flexible(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        child: Semantics(
                          liveRegion: true,
                          child: Text(
                            '${index + 1} of ${turns.length}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.muted,
                            ),
                          ),
                        ),
                      ),
                    ),
                    _pageButton(
                      label: 'Next prompt',
                      icon: Icons.chevron_right,
                      onPressed: index < turns.length - 1
                          ? () => setState(() => _promptIndex = index + 1)
                          : null,
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 14),
              _heading(context, 'Your groups'),
              const SizedBox(height: 4),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                children: [
                  Text(
                    'Your circles and current sparks.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  TextButton(
                    onPressed: () => context.go('/groups'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.text,
                    ),
                    child: const Text(
                      'See all →',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              if (overview.groups.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'Your groups will appear here once you join a circle.',
                  ),
                )
              else
                LayoutBuilder(
                  builder: (context, constraints) {
                    final stack =
                        constraints.maxWidth < 300 ||
                        MediaQuery.textScalerOf(context).scale(14) > 21;
                    final width = stack
                        ? constraints.maxWidth
                        : (constraints.maxWidth - AppSpacing.md) / 2;
                    return Wrap(
                      spacing: AppSpacing.md,
                      runSpacing: AppSpacing.md,
                      children: overview.groups
                          .map(
                            (group) => SizedBox(
                              width: width,
                              child: GroupCard(
                                group: group,
                                isYourTurn: group.holderId == overview.viewerId,
                                highlighted:
                                    group.id == overview.groups.first.id,
                                onTap: () =>
                                    context.push('/groups/${group.id}'),
                              ),
                            ),
                          )
                          .toList(),
                    );
                  },
                ),
              const SizedBox(height: 14),
              _heading(context, 'Recent activity'),
              const SizedBox(height: 8),
              if (overview.activities.isEmpty)
                const Text(
                  'No group activity yet. Your circle’s updates will appear here.',
                )
              else
                ...overview.activities.map(
                  (activity) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: ActivityCard(activity: activity),
                  ),
                ),
            ],
          ),
        );
      },
    ),
  );

  Widget _heading(BuildContext context, String title) => Semantics(
    header: true,
    child: Text(title, style: Theme.of(context).textTheme.titleMedium),
  );

  Widget _pageButton({
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
  }) => IconButton.outlined(
    tooltip: label,
    onPressed: onPressed,
    icon: Icon(icon, size: 24),
    style: IconButton.styleFrom(
      minimumSize: const Size(49, 49),
      backgroundColor: Colors.white,
      foregroundColor: AppColors.text,
      side: const BorderSide(color: AppColors.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
    ),
  );
}

class _CaughtUpCard extends StatelessWidget {
  const _CaughtUpCard();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: AppColors.mint,
      borderRadius: BorderRadius.circular(19),
    ),
    child: Column(
      children: [
        const Icon(
          Icons.check_circle_outline,
          color: AppColors.darkTeal,
          size: 32,
        ),
        const SizedBox(height: 12),
        Text(
          'You’re all caught up!',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        const Text(
          'When someone passes you a spark, its prompt will appear here.',
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/group_details.dart';
import '../models/spark_contribution.dart';
import '../models/today_overview.dart';
import '../repositories/group_repository.dart';
import '../theme/app_colors.dart';
import '../widgets/local_groups_notice.dart';

class PassSparkScreen extends StatefulWidget {
  const PassSparkScreen({
    super.key,
    required this.repository,
    required this.turn,
    required this.answer,
  });
  final GroupRepository repository;
  final SparkGroup turn;
  final String answer;
  @override
  State<PassSparkScreen> createState() => _PassSparkScreenState();
}

class _PassSparkScreenState extends State<PassSparkScreen> {
  late Future<GroupDetails> _details = _load();
  GroupMember? _selected;
  bool _confirming = false;
  bool _saving = false;
  String? _error;
  SparkContribution? _receipt;
  Future<GroupDetails> _load() async {
    final details = await widget.repository.loadGroup(widget.turn.id);
    if (details.viewerId != details.group.holderId ||
        details.group.version != widget.turn.version ||
        details.group.promptId != widget.turn.promptId) {
      throw const GroupInputException(
        'Your turn has changed. Your answer remains saved on this device. Return to the group and check its timeline.',
      );
    }
    return details;
  }

  void _group() => context.go('/groups/${widget.turn.id}');
  Future<void> _pass() async {
    final member = _selected;
    if (_saving || member == null || _receipt != null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final result = await widget.repository.passSpark(
        turn: widget.turn,
        recipientId: member.id,
        answer: widget.answer,
      );
      if (mounted) {
        setState(() {
          _receipt = result;
          _saving = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e is GroupInputException
              ? e.message
              : 'The pass could not be confirmed. Your draft is safe. Retry with the same answer and recipient, or check the group timeline.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving && _receipt == null,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop && _receipt != null) _group();
    },
    child: Scaffold(
      appBar: AppBar(
        title: Text(
          _receipt != null
              ? 'Spark passed!'
              : _confirming
              ? 'Confirm recipient'
              : 'Pass the spark',
        ),
        automaticallyImplyLeading: false,
        leading: _receipt != null
            ? null
            : IconButton(
                tooltip: 'Back',
                onPressed: _saving
                    ? null
                    : () {
                        if (_confirming) {
                          setState(() {
                            _confirming = false;
                            _error = null;
                          });
                        } else {
                          Navigator.of(context).pop();
                        }
                      },
                icon: const Icon(Icons.arrow_back),
              ),
      ),
      body: _receipt != null
          ? _success(context, _receipt!)
          : FutureBuilder<GroupDetails>(
              future: _details,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      Text(
                        snapshot.error is GroupInputException
                            ? (snapshot.error! as GroupInputException).message
                            : 'The group members could not be loaded. Your draft is still saved.',
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () => setState(() {
                          _details = _load();
                          _selected = null;
                        }),
                        child: const Text('Try again'),
                      ),
                      TextButton(
                        onPressed: _group,
                        child: const Text('Back to group'),
                      ),
                    ],
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final details = snapshot.requireData;
                final members = details.members
                    .where((m) => m.id != details.viewerId)
                    .toList();
                return ListView(
                  key: ValueKey(_confirming),
                  padding: const EdgeInsets.all(24),
                  children: [
                    if (widget.repository.isLocalPreview)
                      const LocalGroupsNotice(),
                    Text(
                      widget.turn.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    if (!_confirming) ...[
                      const Text(
                        'Choose another group member to receive the spark.',
                      ),
                      const SizedBox(height: 20),
                      if (members.isEmpty)
                        const Text(
                          'There are no other members yet. Invite a member before passing. Your answer is still saved locally.',
                        ),
                      for (final member in members)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Material(
                            color: _selected?.id == member.id
                                ? AppColors.mint
                                : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () => setState(() => _selected = member),
                              child: Semantics(
                                selected: _selected?.id == member.id,
                                button: true,
                                child: Padding(
                                  padding: const EdgeInsets.all(18),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              member.name,
                                              style: Theme.of(
                                                context,
                                              ).textTheme.titleMedium,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Member of ${widget.turn.name}',
                                              style: const TextStyle(
                                                color: AppColors.muted,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Icon(
                                        _selected?.id == member.id
                                            ? Icons.radio_button_checked
                                            : Icons.radio_button_off,
                                        color: AppColors.teal,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),
                      TextButton.icon(
                        onPressed: () => setState(() {
                          _details = _load();
                          _selected = null;
                        }),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Refresh members'),
                      ),
                      const Text(
                        'Your answer is still a local draft. The recipient will be checked again when you confirm.',
                      ),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: _selected == null
                            ? null
                            : () => setState(() => _confirming = true),
                        child: const Text('Continue'),
                      ),
                    ] else ...[
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
                              'Pass to ${_selected!.name}?',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 8),
                            const Text('Confirmed group member'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Prompt',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(widget.turn.prompt),
                      const SizedBox(height: 20),
                      Text(
                        'Your answer',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(widget.answer),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Confirming shares this answer in the group timeline and passes the spark. Nothing is shared before you confirm.',
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            _error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: _saving ? null : _pass,
                        child: Text(_saving ? 'Passing…' : 'Confirm pass'),
                      ),
                      TextButton(
                        onPressed: _saving
                            ? null
                            : () => setState(() {
                                _confirming = false;
                                _error = null;
                              }),
                        child: const Text('Choose another member'),
                      ),
                    ],
                  ],
                );
              },
            ),
    ),
  );
  Widget _success(BuildContext context, SparkContribution receipt) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      const SizedBox(height: 24),
      const Icon(Icons.check, size: 80, color: AppColors.teal),
      const SizedBox(height: 24),
      Text(
        'Spark passed to ${receipt.recipientName}',
        style: Theme.of(context).textTheme.headlineSmall,
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 16),
      Text(
        widget.repository.isLocalPreview
            ? 'Preview only. The answer and pass were saved in this session.'
            : 'Your answer was saved in ${widget.turn.name} and the spark was passed.',
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 24),
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.mint,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          'Recipient · ${receipt.recipientName}\n${widget.turn.name}',
        ),
      ),
      const SizedBox(height: 32),
      FilledButton(onPressed: _group, child: const Text('Back to group')),
    ],
  );
}

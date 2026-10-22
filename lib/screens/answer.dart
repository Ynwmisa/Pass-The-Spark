import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/answer_draft_controller.dart';
import '../models/answer_draft.dart';
import '../models/today_overview.dart';
import '../repositories/today_repository.dart';
import '../repositories/group_repository.dart';
import 'pass_spark.dart';
import '../services/draft_store.dart';
import '../theme/app_colors.dart';

class AnswerScreen extends StatefulWidget {
  const AnswerScreen({
    super.key,
    required this.groupId,
    required this.repository,
    required this.draftStore,
  });
  final String groupId;
  final TodayRepository repository;
  final DraftStore draftStore;

  @override
  State<AnswerScreen> createState() => _AnswerScreenState();
}

class _AnswerScreenState extends State<AnswerScreen> {
  late Future<TodayOverview> _overview = widget.repository.loadToday();

  @override
  Widget build(BuildContext context) => FutureBuilder<TodayOverview>(
    future: _overview,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Scaffold(
          appBar: AppBar(title: const Text('Answer prompt')),
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Your turn could not be loaded.'),
                TextButton(
                  onPressed: () => setState(() {
                    _overview = widget.repository.loadToday();
                  }),
                  child: const Text('Try again'),
                ),
              ],
            ),
          ),
        );
      }
      final overview = snapshot.data;
      if (overview == null) {
        return Scaffold(
          appBar: AppBar(title: const Text('Answer prompt')),
          body: const Center(child: CircularProgressIndicator()),
        );
      }
      SparkGroup? group;
      for (final item in overview.groups) {
        if (item.id == widget.groupId) group = item;
      }
      if (group == null || group.holderId != overview.viewerId) {
        return Scaffold(
          appBar: AppBar(title: const Text('Answer prompt')),
          body: const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'This prompt is not currently your turn. '
              'Any earlier draft remains on this device.',
            ),
          ),
        );
      }
      return _AnswerEditor(
        group: group,
        viewerId: overview.viewerId,
        repository: widget.repository,
        store: widget.draftStore,
      );
    },
  );
}

class _AnswerEditor extends StatefulWidget {
  const _AnswerEditor({
    required this.group,
    required this.viewerId,
    required this.repository,
    required this.store,
  });
  final SparkGroup group;
  final String viewerId;
  final TodayRepository repository;
  final DraftStore store;

  @override
  State<_AnswerEditor> createState() => _AnswerEditorState();
}

class _AnswerEditorState extends State<_AnswerEditor>
    with WidgetsBindingObserver {
  final _text = TextEditingController();
  late final AnswerDraftController _draft;
  bool _canPop = false;
  bool _leaving = false;
  bool _continuing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _draft = AnswerDraftController(
      key: DraftKey(
        userId: widget.viewerId,
        groupId: widget.group.id,
        promptId: widget.group.promptId,
      ),
      prompt: widget.group.prompt,
      store: widget.store,
    );
    unawaited(_load());
  }

  Future<void> _load() async {
    await _draft.load();
    if (mounted && !_draft.loadFailed) _text.text = _draft.text;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      unawaited(_draft.saveNow());
    }
  }

  Future<void> _leave() async {
    if (_leaving) return;
    _leaving = true;
    var saved = true;
    if (!_draft.loading && !_draft.loadFailed) saved = await _draft.saveNow();
    if (!mounted) return;
    if (!saved) {
      final leaveAnyway = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Your latest changes are not saved'),
          content: const Text(
            'Stay here to try again, or leave without saving '
            'the latest changes. Your last saved draft will be kept.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Stay and retry'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Leave without saving'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (leaveAnyway != true) {
        _leaving = false;
        return;
      }
    }
    setState(() => _canPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context);
    });
  }

  Future<void> _continue() async {
    if (_continuing || _leaving || !_draft.canContinue) return;
    setState(() => _continuing = true);
    try {
      if (!await _draft.saveNow() || !mounted || _leaving) return;
      final latest = await widget.repository.loadToday();
      if (!mounted || _leaving) return;
      final eligible =
          latest.viewerId == widget.viewerId &&
          latest.yourTurns.any(
            (group) =>
                group.id == widget.group.id &&
                group.promptId == widget.group.promptId &&
                group.prompt == widget.group.prompt &&
                group.version == widget.group.version,
          );
      if (!eligible) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Your turn has changed. Your draft is still saved locally.',
            ),
          ),
        );
        return;
      }
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => widget.repository is GroupRepository
              ? PassSparkScreen(
                  repository: widget.repository as GroupRepository,
                  turn: widget.group,
                  answer: _draft.text,
                )
              : AnswerReviewScreen(group: widget.group, answer: _draft.text),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Your turn could not be checked. Your draft is still saved.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _continuing = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _text.dispose();
    _draft.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _canPop,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) unawaited(_leave());
    },
    child: Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.background,
        leading: IconButton(
          tooltip: 'Back',
          onPressed: _leave,
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text(
          'Answer prompt',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListenableBuilder(
          listenable: _draft,
          builder: (context, _) {
            if (_draft.loading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (_draft.loadFailed) {
              return Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Your saved draft could not be opened. '
                      'It has not been replaced.',
                    ),
                    TextButton(
                      onPressed: _load,
                      child: const Text('Try loading again'),
                    ),
                  ],
                ),
              );
            }
            return ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.mint,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.group.name.toUpperCase(),
                        style: const TextStyle(
                          color: AppColors.darkTeal,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.group.prompt,
                        style: const TextStyle(
                          color: AppColors.text,
                          fontSize: 16,
                          height: 1.4,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                if (_draft.promptChanged) ...[
                  const Text(
                    'This prompt changed since you wrote the draft. '
                    'Review the question and your answer before continuing.',
                  ),
                  TextButton(
                    onPressed: _draft.acknowledgePrompt,
                    child: const Text('I have reviewed the updated prompt'),
                  ),
                  const SizedBox(height: 12),
                ],
                Semantics(
                  header: true,
                  child: Text(
                    'Your answer',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const SizedBox(height: 12),
                Semantics(
                  label: 'Your answer',
                  child: TextField(
                    controller: _text,
                    onTapOutside: (_) => FocusScope.of(context).unfocus(),
                    onChanged: _draft.updateText,
                    minLines: 5,
                    maxLines: 8,
                    maxLength: 300,
                    maxLengthEnforcement: MaxLengthEnforcement.none,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: 'Share one useful update with your group…',
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.all(16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      errorText: _draft.characterCount > 300
                          ? 'Keep your answer to 300 characters or fewer.'
                          : null,
                    ),
                    style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Semantics(
                  liveRegion: _draft.saveFailed,
                  child: Text(
                    _draft.status,
                    style: TextStyle(
                      color: _draft.saveFailed
                          ? Theme.of(context).colorScheme.error
                          : AppColors.darkTeal,
                    ),
                  ),
                ),
                if (_draft.saveFailed)
                  TextButton(
                    onPressed: _draft.saveNow,
                    child: const Text('Try saving again'),
                  ),
                const SizedBox(height: 24),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.navy,
                    foregroundColor: Colors.white,
                  ),
                  onPressed:
                      _draft.canContinue && !_draft.saving && !_continuing
                      ? _continue
                      : null,
                  child: Text(
                    _continuing
                        ? 'Checking your turn…'
                        : 'Save answer & continue',
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Saved only on this device. Your group can read your '
                  'answer after a successful pass.',
                ),
                if (_draft.text.trim().isEmpty) ...[
                  const SizedBox(height: 8),
                  const Text('Write an answer before continuing.'),
                ],
              ],
            );
          },
        ),
      ),
    ),
  );
}

class AnswerReviewScreen extends StatelessWidget {
  const AnswerReviewScreen({
    super.key,
    required this.group,
    required this.answer,
  });
  final SparkGroup group;
  final String answer;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Review answer')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(group.name, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Text(group.prompt, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              answer,
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.text,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Draft saved locally. Nothing has been shared and the '
            'spark has not moved. Recipient selection is the next feature.',
          ),
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Back to edit'),
          ),
        ],
      ),
    ),
  );
}

import 'dart:async';

import 'package:characters/characters.dart';
import 'package:flutter/foundation.dart';

import '../models/answer_draft.dart';
import '../services/draft_store.dart';

class AnswerDraftController extends ChangeNotifier {
  AnswerDraftController({
    required this.key,
    required this.prompt,
    required this.store,
  }) : _draftPrompt = prompt;

  final DraftKey key;
  final String prompt;
  final DraftStore store;
  String _draftPrompt;
  String text = '';
  bool loading = true;
  bool saving = false;
  bool loadFailed = false;
  bool saveFailed = false;
  bool _disposed = false;
  int _revision = 0;
  int _savedRevision = 0;
  Future<bool>? _activeSave;

  int get characterCount => text.characters.length;
  bool get promptChanged => _draftPrompt != prompt;
  bool get hasChanges => _revision != _savedRevision;
  bool get isValid => text.trim().isNotEmpty && characterCount <= 300;
  bool get canContinue => !loading && !loadFailed && !promptChanged && isValid;
  String get status {
    if (saveFailed) return 'Draft could not be saved';
    if (saving || hasChanges) return 'Saving draft…';
    if (text.isEmpty) return 'Your draft stays on this device';
    return 'Draft saved locally';
  }

  Future<void> load() async {
    loading = true;
    loadFailed = false;
    _notify();
    try {
      final draft = await store.read(key);
      if (_disposed) return;
      text = draft?.text ?? '';
      _draftPrompt = draft?.prompt ?? prompt;
      _revision = 0;
      _savedRevision = 0;
    } catch (_) {
      loadFailed = true;
    } finally {
      loading = false;
      _notify();
    }
  }

  void updateText(String value) {
    if (loading || loadFailed || text == value) return;
    text = value;
    _revision++;
    _notify();
    unawaited(saveNow());
  }

  void acknowledgePrompt() {
    _draftPrompt = prompt;
    _revision++;
    _notify();
    unawaited(saveNow());
  }

  Future<bool> saveNow() async {
    if (loading || loadFailed) return false;
    final active = _activeSave;
    if (active != null) return active;
    if (!hasChanges) return !saveFailed;
    final task = _persist();
    _activeSave = task;
    try {
      return await task;
    } finally {
      _activeSave = null;
    }
  }

  Future<bool> _persist() async {
    saving = true;
    saveFailed = false;
    _notify();
    try {
      while (hasChanges) {
        final revision = _revision;
        final draft = AnswerDraft(
          key: key,
          prompt: _draftPrompt,
          text: text,
          savedAt: DateTime.now(),
        );
        await store.write(draft);
        _savedRevision = revision;
      }
      return true;
    } catch (_) {
      saveFailed = true;
      return false;
    } finally {
      saving = false;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

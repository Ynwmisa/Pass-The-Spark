import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pass_the_spark/controllers/answer_draft_controller.dart';
import 'package:pass_the_spark/models/answer_draft.dart';

import 'helpers/memory_draft_store.dart';

class SlowDraftStore extends MemoryDraftStore {
  final gate = Completer<void>();
  @override
  Future<void> write(AnswerDraft draft) async {
    await gate.future;
    await super.write(draft);
  }
}

void main() {
  const key = DraftKey(
    userId: 'student',
    groupId: 'mobile',
    promptId: 'progress',
  );
  late MemoryDraftStore store;
  late AnswerDraftController controller;

  setUp(() {
    store = MemoryDraftStore();
    controller = AnswerDraftController(
      key: key,
      prompt: 'What helped?',
      store: store,
    );
  });
  tearDown(() => controller.dispose());

  test(
    'blank and long answers cannot continue; emoji count as visible characters',
    () async {
      await controller.load();
      controller.updateText('   ');
      await controller.saveNow();
      expect(controller.canContinue, isFalse);
      controller.updateText('👨‍👩‍👧‍👦');
      await controller.saveNow();
      expect(controller.characterCount, 1);
      expect(controller.canContinue, isTrue);
      controller.updateText('a' * 301);
      await controller.saveNow();
      expect(controller.canContinue, isFalse);
      expect((await store.read(key))!.text, hasLength(301));
    },
  );

  test('failed save retains latest text and can be retried', () async {
    await controller.load();
    store.failWrite = true;
    controller.updateText('Keep this answer.');
    expect(await controller.saveNow(), isFalse);
    expect(controller.saveFailed, isTrue);
    expect(controller.hasChanges, isTrue);
    expect(controller.text, 'Keep this answer.');
    store.failWrite = false;
    expect(await controller.saveNow(), isTrue);
    expect((await store.read(key))!.text, 'Keep this answer.');
    expect(controller.status, 'Draft saved locally');
  });

  test(
    'typing during a slow save eventually stores the newest revision',
    () async {
      final slow = SlowDraftStore();
      final current = AnswerDraftController(
        key: key,
        prompt: 'What helped?',
        store: slow,
      );
      await current.load();
      current.updateText('First');
      current.updateText('Newest');
      slow.gate.complete();
      expect(await current.saveNow(), isTrue);
      expect((await slow.read(key))!.text, 'Newest');
      current.dispose();
    },
  );

  test('updated prompt requires review without losing the old draft', () async {
    await store.write(
      AnswerDraft(
        key: key,
        prompt: 'Earlier question',
        text: 'My existing answer',
        savedAt: DateTime.now(),
      ),
    );
    await controller.load();
    expect(controller.promptChanged, isTrue);
    expect(controller.canContinue, isFalse);
    controller.updateText('Reviewed answer');
    await controller.saveNow();
    expect((await store.read(key))!.prompt, 'Earlier question');
    controller.acknowledgePrompt();
    await controller.saveNow();
    expect(controller.promptChanged, isFalse);
    expect(controller.canContinue, isTrue);
    expect((await store.read(key))!.prompt, 'What helped?');
  });

  test('failed loading does not silently overwrite saved data', () async {
    store.failRead = true;
    await controller.load();
    controller.updateText('Do not write');
    expect(await controller.saveNow(), isFalse);
    expect(controller.loadFailed, isTrue);
    expect(store.writes, 0);
  });

  test('fresh controller restores the saved answer', () async {
    await controller.load();
    controller.updateText('Saved answer');
    await controller.saveNow();
    final next = AnswerDraftController(
      key: key,
      prompt: 'What helped?',
      store: store,
    );
    await next.load();
    expect(next.text, 'Saved answer');
    expect(next.hasChanges, isFalse);
    next.dispose();
  });
}

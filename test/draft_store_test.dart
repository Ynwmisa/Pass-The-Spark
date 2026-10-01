import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pass_the_spark/models/answer_draft.dart';
import 'package:pass_the_spark/services/draft_store.dart';

void main() {
  late Directory directory;
  late FileDraftStore store;
  const key = DraftKey(
    userId: 'student',
    groupId: 'mobile',
    promptId: 'progress',
  );
  AnswerDraft draft(DraftKey key, String text) => AnswerDraft(
    key: key,
    prompt: 'What helped?',
    text: text,
    savedAt: DateTime.utc(2026, 10, 28),
  );

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('spark_draft_test_');
    store = FileDraftStore(directoryProvider: () async => directory);
  });
  tearDown(() async => directory.delete(recursive: true));

  test('new storage instance recovers a completed draft from disk', () async {
    await store.write(draft(key, 'We finished the prototype.'));
    final reopened = FileDraftStore(directoryProvider: () async => directory);
    final recovered = await reopened.read(key);
    expect(recovered!.text, 'We finished the prototype.');
    expect(recovered.prompt, 'What helped?');
    expect(recovered.savedAt, DateTime.utc(2026, 10, 28));
  });

  test('drafts are isolated by user, group and prompt', () async {
    const keys = [
      key,
      DraftKey(userId: 'other', groupId: 'mobile', promptId: 'progress'),
      DraftKey(userId: 'student', groupId: 'ux', promptId: 'progress'),
      DraftKey(userId: 'student', groupId: 'mobile', promptId: 'next'),
    ];
    for (var i = 0; i < keys.length; i++) {
      await store.write(draft(keys[i], 'Answer $i'));
    }
    for (var i = 0; i < keys.length; i++) {
      expect((await store.read(keys[i]))!.text, 'Answer $i');
    }
  });

  test('overlapping writes preserve the latest complete value', () async {
    await Future.wait([
      store.write(draft(key, 'First version')),
      store.write(draft(key, 'Latest version')),
    ]);
    expect((await store.read(key))!.text, 'Latest version');
  });

  test('corrupted draft is reported without replacing the file', () async {
    await store.write(draft(key, 'Original'));
    final file =
        (await Directory(
                  '${directory.path}/answer_drafts',
                ).list().where((item) => item.path.endsWith('.json')).toList())
                .single
            as File;
    await file.writeAsString('{broken');
    await expectLater(store.read(key), throwsFormatException);
    expect(await file.readAsString(), '{broken');
  });

  test('missing draft returns no content', () async {
    expect(await store.read(key), isNull);
  });
}

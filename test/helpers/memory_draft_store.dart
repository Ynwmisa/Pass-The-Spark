import 'dart:convert';
import 'package:pass_the_spark/models/answer_draft.dart';
import 'package:pass_the_spark/services/draft_store.dart';

class MemoryDraftStore implements DraftStore {
  final Map<String, AnswerDraft> drafts = {};
  bool failRead = false;
  bool failWrite = false;
  int writes = 0;

  String _id(DraftKey key) => jsonEncode(key.parts);

  @override
  Future<AnswerDraft?> read(DraftKey key) async {
    if (failRead) throw StateError('Read failed');
    return drafts[_id(key)];
  }

  @override
  Future<void> write(AnswerDraft draft) async {
    writes++;
    if (failWrite) throw StateError('Write failed');
    drafts[_id(draft.key)] = draft;
  }
}

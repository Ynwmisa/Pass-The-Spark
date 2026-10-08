import 'package:flutter_test/flutter_test.dart';
import 'package:pass_the_spark/models/group_details.dart';
import 'package:pass_the_spark/repositories/local_group_repository.dart';

void main() {
  test(
    'creating a circle makes one organiser and one consistent holder',
    () async {
      final repo = LocalGroupRepository(seedDemo: false);
      addTearDown(repo.dispose);
      final created = await repo.createGroup('  Project Circle  ');
      expect(created.group.name, 'Project Circle');
      expect(created.members, hasLength(1));
      expect(created.members.single.isOrganiser, isTrue);
      expect(created.group.holderId, created.members.single.id);
      expect(created.group.memberCount, created.members.length);
      final today = await repo.loadToday();
      expect(today.yourTurns.single.id, created.group.id);
      final second = await repo.createGroup('Another Circle');
      expect(second.group.id, isNot(created.group.id));
    },
  );

  test(
    'invalid names cannot change group state, including direct repository calls',
    () async {
      final repo = LocalGroupRepository(seedDemo: false);
      addTearDown(repo.dispose);
      for (final name in ['', '   ', 'a\nb', List.filled(61, 'a').join()]) {
        await expectLater(
          repo.createGroup(name),
          throwsA(isA<GroupInputException>()),
        );
      }
      expect((await repo.loadGroups()).groups, isEmpty);
      // One visible emoji is not counted by its multiple code units.
      await repo.createGroup(List.filled(60, '👩🏽‍💻').join());
      expect((await repo.loadGroups()).groups, hasLength(1));
    },
  );

  test(
    'repeated join requests are idempotent and cannot open private data',
    () async {
      final repo = LocalGroupRepository(seedDemo: false);
      addTearDown(repo.dispose);
      var changes = 0;
      repo.addListener(() => changes++);
      final first = await repo.requestToJoin(' study26 ');
      final again = await repo.requestToJoin('STUDY26');
      expect(again, same(first));
      expect(changes, 1);
      final overview = await repo.loadGroups();
      expect(overview.requests, hasLength(1));
      expect(overview.groups, isEmpty);
      expect((await repo.loadToday()).yourTurns, isEmpty);
      await expectLater(
        repo.loadGroup(first.groupId),
        throwsA(isA<GroupInputException>()),
      );
    },
  );

  test('unknown and malformed codes leave requests unchanged', () async {
    final repo = LocalGroupRepository();
    addTearDown(repo.dispose);
    for (final code in ['?', '', 'WRONG77']) {
      await expectLater(
        repo.requestToJoin(code),
        throwsA(isA<GroupInputException>()),
      );
    }
    expect((await repo.loadGroups()).requests, isEmpty);
    expect((await repo.loadGroups()).groups, hasLength(2));
  });

  test(
    'group snapshots are immutable and session instances stay independent',
    () async {
      final first = LocalGroupRepository();
      final second = LocalGroupRepository(seedDemo: false);
      addTearDown(first.dispose);
      addTearDown(second.dispose);
      final snapshot = await first.loadGroups();
      expect(() => snapshot.groups.clear(), throwsUnsupportedError);
      final detail = await first.loadGroup(snapshot.groups.first.id);
      expect(() => detail.members.clear(), throwsUnsupportedError);
      await first.createGroup('New');
      expect(snapshot.groups, hasLength(2));
      expect((await second.loadGroups()).groups, isEmpty);
    },
  );
}

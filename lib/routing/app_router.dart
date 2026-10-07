import '../repositories/group_repository.dart';
import '../screens/groups/groups.dart';
import '../screens/groups/group_detail.dart';
import '../screens/groups/group_form.dart';
import 'package:go_router/go_router.dart';

import '../repositories/today_repository.dart';
import '../screens/answer.dart';
import '../screens/preview.dart';
import '../screens/today.dart';
import '../services/draft_store.dart';
import 'main_scaffold.dart';

GoRouter createAppRouter(
  TodayRepository repository,
  DraftStore draftStore,
  GroupRepository groups,
) => GoRouter(
  routes: [
    GoRoute(
      path: '/answer/:groupId',
      builder: (context, state) => AnswerScreen(
        groupId: state.pathParameters['groupId']!,
        repository: repository,
        draftStore: draftStore,
      ),
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => MainScaffold(navigationShell: shell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => TodayScreen(repository: repository),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/groups',
              builder: (context, state) => GroupsScreen(repository: groups),
              routes: [
                GoRoute(
                  path: 'create',
                  builder: (context, state) =>
                      GroupFormScreen(repository: groups),
                ),
                GoRoute(
                  path: 'join',
                  builder: (context, state) =>
                      GroupFormScreen(repository: groups, join: true),
                ),
                GoRoute(
                  path: ':groupId',
                  builder: (context, state) => GroupDetailScreen(
                    repository: groups,
                    groupId: state.pathParameters['groupId']!,
                  ),
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/journey',
              builder: (context, state) =>
                  PreviewScreen(title: 'Journey', repository: repository),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/profile',
              builder: (context, state) =>
                  PreviewScreen(title: 'Profile', repository: repository),
            ),
          ],
        ),
      ],
    ),
  ],
);

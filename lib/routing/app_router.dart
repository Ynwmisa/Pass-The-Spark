import 'package:go_router/go_router.dart';

import '../repositories/today_repository.dart';
import '../screens/preview.dart';
import '../screens/today.dart';
import 'main_scaffold.dart';

GoRouter createAppRouter(TodayRepository repository) => GoRouter(
  routes: [
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
              builder: (context, state) =>
                  PreviewScreen(title: 'Groups', repository: repository),
              routes: [
                GoRoute(
                  path: ':groupId',
                  builder: (context, state) => PreviewScreen(
                    title: 'Group preview',
                    repository: repository,
                    groupId: state.pathParameters['groupId'],
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

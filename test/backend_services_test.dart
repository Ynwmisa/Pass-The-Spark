import 'package:pass_the_spark/models/group_details.dart';
import 'package:flutter/material.dart';
import 'package:pass_the_spark/main.dart';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pass_the_spark/models/account.dart';
import 'package:pass_the_spark/services/backend_config.dart';
import 'package:pass_the_spark/services/supabase_account_session.dart';
import 'package:pass_the_spark/repositories/supabase_group_repository.dart';

MockClient jsonClient(Future<http.Response> Function(http.Request) handler) =>
    MockClient((request) async {
      final result = await handler(request);
      return http.Response.bytes(
        result.bodyBytes,
        result.statusCode,
        headers: {...result.headers, 'content-type': 'application/json'},
        request: request,
      );
    });

const userId = '11111111-1111-4111-8111-111111111111';
const groupId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
Map<String, dynamic> sessionJson({String id = userId}) {
  String b64(Object v) =>
      base64Url.encode(utf8.encode(jsonEncode(v))).replaceAll('=', '');
  final expiry =
      DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
      1000;
  return {
    'access_token':
        '${b64({'alg': 'HS256', 'typ': 'JWT'})}.${b64({'exp': expiry, 'sub': id, 'role': 'authenticated'})}.signature',
    'refresh_token': 'test-refresh',
    'expires_in': 3600,
    'token_type': 'bearer',
    'user': {
      'id': id,
      'email': 'student@example.com',
      'email_confirmed_at': '2026-10-28T00:00:00Z',
      'app_metadata': {},
      'user_metadata': {'display_name': 'Student'},
      'aud': 'authenticated',
      'created_at': '2026-10-28T00:00:00Z',
    },
  };
}

Map<String, dynamic> groupJson() => {
  'id': groupId,
  'name': 'Circle',
  'member_count': 1,
  'holder_id': userId,
  'holder_name': 'Student',
  'prompt_id': 'first-prompt',
  'prompt': 'What helped?',
};
void main() {
  test(
    'configuration rejects missing or insecure hosted URLs and secret keys',
    () {
      expect(
        const BackendConfig(url: '', publishableKey: '').validationError,
        isNotNull,
      );
      expect(
        const BackendConfig(
          url: 'http://example.com',
          publishableKey: 'x',
        ).validationError,
        isNotNull,
      );
      expect(
        const BackendConfig(
          url: 'https://example.supabase.co',
          publishableKey: 'sb_secret_x',
        ).validationError,
        isNotNull,
      );
      expect(
        const BackendConfig(
          url: 'https://example.supabase.co',
          publishableKey: 'sb_publishable_test',
        ).validationError,
        isNull,
      );
    },
  );
  test(
    'account service maps server rejection without exposing raw details',
    () async {
      final client = SupabaseClient(
        'https://example.supabase.co',
        'test-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: jsonClient(
          (r) async => http.Response(
            jsonEncode({
              'error': 'invalid_grant',
              'error_code': 'invalid_credentials',
              'msg': 'sensitive raw detail',
            }),
            400,
          ),
        ),
      );
      final service = SupabaseAccountSession(client);
      await expectLater(
        service.signIn('student@example.com', 'wrong'),
        throwsA(
          isA<AccountException>().having(
            (e) => e.message,
            'message',
            'The email or password is incorrect.',
          ),
        ),
      );
      expect(service.account, isNull);
      service.dispose();
      await client.dispose();
    },
  );
  test('SDK sign-in and local sign-out change the account identity', () async {
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: jsonClient(
        (r) async => r.url.path.endsWith('/logout')
            ? http.Response('', 204)
            : http.Response(jsonEncode(sessionJson()), 200),
      ),
    );
    final service = SupabaseAccountSession(client);
    await service.signIn('student@example.com', 'password');
    expect(service.account?.id, userId);
    await service.signOut();
    expect(service.account, isNull);
    service.dispose();
    await client.dispose();
  });
  test(
    'hosted groups parse server identity and retry creation with the same request id',
    () async {
      final requestIds = <String>[];
      var detailCalls = 0;
      final client = SupabaseClient(
        'https://example.supabase.co',
        'test-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: jsonClient((r) async {
          if (r.url.path.contains('/auth/')) {
            return http.Response(jsonEncode(sessionJson()), 200);
          }
          if (r.url.path.endsWith('/create_group')) {
            requestIds.add(
              (jsonDecode(r.body) as Map)['p_request_id'] as String,
            );
            return http.Response(jsonEncode(groupId), 200);
          }
          if (r.url.path.endsWith('/group_context')) {
            if (detailCalls++ == 0) {
              return http.Response(
                jsonEncode({'code': 'XX000', 'message': 'load failed'}),
                400,
              );
            }
            return http.Response(
              jsonEncode({
                'viewer_id': userId,
                'group': groupJson(),
                'invite_code': '123456ABCDEF',
                'members': [
                  {'id': userId, 'name': 'Student', 'is_organiser': true},
                ],
              }),
              200,
            );
          }
          return http.Response(
            jsonEncode({
              'viewer_id': userId,
              'groups': [groupJson()],
              'requests': [],
            }),
            200,
          );
        }),
      );
      await client.auth.signInWithPassword(
        email: 'student@example.com',
        password: 'password',
      );
      final repo = SupabaseGroupRepository(client);
      await expectLater(repo.createGroup('Circle'), throwsA(isA<Object>()));
      final group = await repo.createGroup('Circle');
      expect(group.viewerId, userId);
      expect(group.inviteCode, '123456ABCDEF');
      expect(requestIds, hasLength(2));
      expect(requestIds[0], requestIds[1]);
      expect((await repo.loadToday()).yourTurns.single.id, groupId);
      await client.auth.signOut(scope: SignOutScope.local);
      await expectLater(repo.loadGroups(), throwsA(isA<Object>()));
      repo.dispose();
      await client.dispose();
    },
  );

  testWidgets(
    'logout removes private navigation before another account signs in',
    (tester) async {
      var nextUser = userId;
      final client = (await tester.runAsync(
        () async => SupabaseClient(
          'https://example.supabase.co',
          'test-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
          httpClient: jsonClient((r) async {
            if (r.url.path.endsWith('/logout')) return http.Response('', 204);
            if (r.url.path.contains('/auth/')) {
              return http.Response(jsonEncode(sessionJson(id: nextUser)), 200);
            }
            return http.Response(
              jsonEncode({
                'viewer_id': nextUser,
                'groups': nextUser == userId ? [groupJson()] : [],
                'requests': [],
              }),
              200,
            );
          }),
        ),
      ))!;
      await tester.runAsync(
        () => client.auth.signInWithPassword(
          email: 'first@example.com',
          password: 'password',
        ),
      );

      await tester.pumpWidget(BackendApplication(client: client));

      await tester.pumpAndSettle();

      expect(find.text('Circle'), findsWidgets);
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Sign out'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Sign out'));
      await tester.pumpAndSettle();
      expect(find.text('Welcome back'), findsOneWidget);
      expect(find.text('Circle'), findsNothing);
      nextUser = '22222222-2222-4222-8222-222222222222';
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'second@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'password',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pumpAndSettle();
      expect(find.text('Circle'), findsNothing);
      expect(
        find.text('Your groups will appear here once you join a circle.'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();

      await tester.runAsync(client.dispose);
    },
  );

  test(
    'approval operations map pending names and notify only after a confirmed write',
    () async {
      var fail = true;
      var calls = 0;
      final client = SupabaseClient(
        'https://example.supabase.co',
        'test-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: jsonClient((r) async {
          if (r.url.path.contains('/auth/')) {
            return http.Response(jsonEncode(sessionJson()), 200);
          }
          if (r.url.path.endsWith('/list_group_requests')) {
            expect((jsonDecode(r.body) as Map)['p_group_id'], groupId);
            return http.Response(
              jsonEncode([
                {'id': 'request-1', 'display_name': 'Riley'},
              ]),
              200,
            );
          }
          if (r.url.path.endsWith('/approve_join_request')) {
            calls++;
            expect((jsonDecode(r.body) as Map)['p_request_id'], 'request-1');
            return fail
                ? http.Response(
                    jsonEncode({
                      'code': '42501',
                      'message': 'Only the organiser may approve.',
                    }),
                    403,
                  )
                : http.Response('null', 200);
          }
          return http.Response('{}', 200);
        }),
      );
      await client.auth.signInWithPassword(
        email: 'student@example.com',
        password: 'password',
      );
      final repo = SupabaseGroupRepository(client);
      var changes = 0;
      repo.addListener(() => changes++);
      final requests = await repo.loadMembershipRequests(groupId);
      expect(requests.single.displayName, 'Riley');
      await expectLater(
        repo.approveMembershipRequest('request-1'),
        throwsA(isA<GroupInputException>()),
      );
      expect(changes, 0);
      fail = false;
      await repo.approveMembershipRequest('request-1');
      expect(changes, 1);
      expect(calls, 2);
      repo.dispose();
      await client.dispose();
    },
  );
  test(
    'leave sends the group ID and notifies only after server confirmation',
    () async {
      var fail = true;
      final client = SupabaseClient(
        'https://example.supabase.co',
        'test-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: jsonClient((r) async {
          if (r.url.path.contains('/auth/')) {
            return http.Response(jsonEncode(sessionJson()), 200);
          }
          expect(r.url.path.endsWith('/leave_group'), isTrue);
          expect((jsonDecode(r.body) as Map)['p_group_id'], groupId);
          return fail
              ? http.Response(
                  jsonEncode({
                    'code': '22023',
                    'message': 'Pass the spark before leaving.',
                  }),
                  400,
                )
              : http.Response('null', 200);
        }),
      );
      await client.auth.signInWithPassword(
        email: 'student@example.com',
        password: 'password',
      );
      final repo = SupabaseGroupRepository(client);
      var changes = 0;
      repo.addListener(() => changes++);
      await expectLater(
        repo.leaveGroup(groupId),
        throwsA(isA<GroupInputException>()),
      );
      expect(changes, 0);
      fail = false;
      await repo.leaveGroup(groupId);
      expect(changes, 1);
      repo.dispose();
      await client.dispose();
    },
  );
  test(
    'invitation SDK maps inbox, preserves send retry ID and confirms response before notifying',
    () async {
      var fail = true;
      final requestIds = <String>[];
      final client = SupabaseClient(
        'https://example.supabase.co',
        'test-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: jsonClient((r) async {
          if (r.url.path.contains('/auth/')) {
            return http.Response(jsonEncode(sessionJson()), 200);
          }
          if (r.url.path.endsWith('/my_group_overview')) {
            return http.Response(
              jsonEncode({
                'viewer_id': userId,
                'groups': [],
                'requests': [],
                'invitations': [
                  {
                    'id': 'invite-1',
                    'group_id': groupId,
                    'group_name': 'Circle',
                  },
                ],
              }),
              200,
            );
          }
          final params = jsonDecode(r.body) as Map;
          if (r.url.path.endsWith('/invite_group_member')) {
            expect(params['p_group_id'], groupId);
            expect(params['p_email'], 'student@example.com');
            requestIds.add(params['p_request_id'] as String);
          } else {
            expect(r.url.path.endsWith('/respond_to_group_invitation'), isTrue);
            expect(params['p_invitation_id'], 'invite-1');
            expect(params['p_accept'], isFalse);
          }
          return fail
              ? http.Response(
                  jsonEncode({'code': '22023', 'message': 'Please try again.'}),
                  400,
                )
              : http.Response('null', 200);
        }),
      );
      await client.auth.signInWithPassword(
        email: 'student@example.com',
        password: 'password',
      );
      final repo = SupabaseGroupRepository(client);
      var changes = 0;
      repo.addListener(() => changes++);
      final overview = await repo.loadGroups();
      expect(overview.invitations.single.groupName, 'Circle');
      await expectLater(
        repo.inviteMember(groupId, ' STUDENT@EXAMPLE.COM '),
        throwsA(isA<GroupInputException>()),
      );
      expect(changes, 0);
      fail = false;
      await repo.inviteMember(groupId, 'student@example.com');
      expect(requestIds[0], requestIds[1]);
      expect(changes, 1);
      fail = true;
      await expectLater(
        repo.respondToInvitation('invite-1', accept: false),
        throwsA(isA<GroupInputException>()),
      );
      expect(changes, 1);
      fail = false;
      await repo.respondToInvitation('invite-1', accept: false);
      expect(changes, 2);
      repo.dispose();
      await client.dispose();
    },
  );
}

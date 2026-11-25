import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:scamgym/api.dart';
import 'package:scamgym/models.dart';
import 'package:scamgym/screens/link_screen.dart';
import 'package:scamgym/screens/message_screen.dart';
import 'package:scamgym/screens/shell.dart';
import 'package:scamgym/screens/train_screen.dart';
import 'package:scamgym/theme.dart';
import 'package:scamgym/widgets/common.dart';

void main() {
  test('Scenario parses the API shape', () {
    final scenario = Scenario.fromJson(const {
      'id': 'kalahari-bank',
      'title': 'The fraud desk that calls you',
      'org': 'Kalahari Bank (fictional)',
      'channel': 'SMS',
      'difficulty': 2,
      'teaser': 'A transaction you never made.',
      'brief': 'A brief.',
      'max_turns': 8,
      'flag_count': 6,
      'accent': 'lime',
    });

    expect(scenario.id, 'kalahari-bank');
    expect(scenario.difficulty, 2);
    expect(scenario.flagCount, 6);
    expect(scenario.maxTurns, 8);
  });

  test('LinkReport handles a missing optional explanation', () {
    final report = LinkReport.fromJson(const {
      'input': 'http://example.com.verify-login.top',
      'score': 55,
      'verdict': 'high',
      'verdict_label': 'Likely phishing',
      'findings': [
        {
          'id': 'suspicious_tld',
          'label': 'High-risk domain ending',
          'detail': 'x',
          'weight': 30,
        },
      ],
    });

    expect(report.score, 55);
    expect(report.verdict, 'high');
    expect(report.findings, hasLength(1));
    expect(report.aiExplanation, isNull);
  });

  testWidgets('ScoreRing shows the score', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: ScoreRing(score: 80))),
      ),
    );
    expect(find.text('80'), findsOneWidget);
    expect(find.text('/100'), findsOneWidget);
  });

  testWidgets('TrainScreen renders on wide viewports and completes a round', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final mockClient = MockClient((request) async {
      final path = request.url.path;
      if (path == '/api/scenarios') {
        return http.Response(
          jsonEncode({
            'scenarios': [
              {
                'id': 'kalahari-bank',
                'title': 'The fraud desk that calls you',
                'org': 'Kalahari Bank (fictional)',
                'channel': 'SMS',
                'difficulty': 2,
                'teaser': 'A transaction you never made.',
                'brief': 'You did not expect a transaction alert.',
                'max_turns': 8,
                'flag_count': 6,
                'accent': 'lime',
              },
            ],
          }),
          200,
        );
      }
      if (path == '/api/health') {
        return http.Response(
          jsonEncode({
            'status': 'ok',
            'ai': true,
            'model': 'gemini-3.5-flash-lite',
            'scenarios': 5,
            'version': '0.1.0',
          }),
          200,
        );
      }
      if (path == '/api/rounds' && request.method == 'POST') {
        return http.Response(
          jsonEncode({
            'round_id': 'round-1',
            'scenario': {
              'id': 'kalahari-bank',
              'title': 'The fraud desk that calls you',
              'org': 'Kalahari Bank (fictional)',
              'channel': 'SMS',
              'difficulty': 2,
              'teaser': 'A transaction you never made.',
              'brief': 'You did not expect a transaction alert.',
              'max_turns': 8,
              'flag_count': 6,
              'accent': 'lime',
            },
            'opening': 'KALAHARI BANK: Reverse now at https://kalahari-bank-secure.example.com/reverse',
            'turn': 0,
            'max_turns': 8,
            'status': 'active',
          }),
          201,
        );
      }
      if (path == '/api/rounds/round-1/messages' && request.method == 'POST') {
        return http.Response(
          jsonEncode({
            'round_id': 'round-1',
            'reply':
                'This is Agent Naledi. Read out the OTP to stop the charge.',
            'turn': 1,
            'max_turns': 8,
            'status': 'active',
            'score': null,
            'limit_reached': false,
          }),
          200,
        );
      }
      if (path == '/api/rounds/round-1/score' && request.method == 'POST') {
        return http.Response(
          jsonEncode({
            'score': 94,
            'grade': 'A',
            'verdict': 'Scam-proof. Nothing important slipped past you.',
            'summary': '1 of 1 planted red flags spotted. 0 risky actions, 1 good move.',
            'flags': {
              'planted': [
                {
                  'id': 'lookalike_link',
                  'label': 'Lookalike link',
                  'explanation': 'Not the bank domain.',
                  'severity': 'high',
                  'spotted': true,
                },
              ],
              'spotted': [],
              'missed': [],
            },
            'actions': [
              {
                'kind': 'refused',
                'label': 'Refused the request',
                'points': 8,
                'source': 'code',
              },
              {
                'kind': 'clicked_link',
                'label': 'Clicked a link',
                'points': -20,
                'source': 'client',
              },
            ],
            'breakdown': {
              'start': 100,
              'flag_bonus': 5,
              'flag_penalty': 0,
              'action_penalty': -20,
              'action_bonus': 8,
            },
            'advice': ['Nothing to fix this round.'],
            'turn_count': 1,
          }),
          200,
        );
      }
      return http.Response('{}', 404);
    });

    final api = ApiClient(baseUrl: 'http://localhost:8080', client: mockClient);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildScamGymTheme(),
        home: Scaffold(body: TrainScreen(api: api)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Pick a scam. Take a round.'), findsOneWidget);
    expect(find.text('Start round'), findsOneWidget);

    await tester.tap(find.text('Start round'));
    await tester.pumpAndSettle();

    expect(find.text('Turn 0 / 8'), findsOneWidget);

    await tester.enterText(
      find.byType(TextField),
      'Who is this? That link looks fake.',
    );
    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();

    expect(find.text('Turn 1 / 8'), findsOneWidget);
    expect(find.textContaining('Agent Naledi'), findsOneWidget);

    await tester.tap(find.text('Weigh in'));
    await tester.pumpAndSettle();

    expect(find.text('Refused the request'), findsOneWidget);
    expect(find.text('Clicked a link'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (w) => w is Text && w.data == '+8' && w.style?.color == AppColors.lime,
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (w) => w is Text && w.data == '-20' && w.style?.color == AppColors.red,
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'HomeShell and TrainScreen are responsive on a 390x844 mobile viewport',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final mockClient = MockClient((request) async {
        final path = request.url.path;
        if (path == '/api/scenarios') {
          return http.Response(
            jsonEncode({
              'scenarios': [
                {
                  'id': 'kalahari-bank',
                  'title': 'The fraud desk that calls you',
                  'org': 'Kalahari Bank (fictional)',
                  'channel': 'SMS',
                  'difficulty': 2,
                  'teaser': 'A transaction you never made.',
                  'brief': 'You did not expect a transaction alert.',
                  'max_turns': 8,
                  'flag_count': 6,
                  'accent': 'lime',
                },
              ],
            }),
            200,
          );
        }
        if (path == '/api/health') {
          return http.Response(
            jsonEncode({
              'status': 'ok',
              'ai': true,
              'model': 'gemini-3.5-flash-lite',
              'scenarios': 5,
              'version': '0.1.0',
            }),
            200,
          );
        }
        if (path == '/api/rounds' && request.method == 'POST') {
          return http.Response(
            jsonEncode({
              'round_id': 'round-mob',
              'scenario': {
                'id': 'kalahari-bank',
                'title': 'The fraud desk that calls you',
                'org': 'Kalahari Bank (fictional)',
                'channel': 'SMS',
                'difficulty': 2,
                'teaser': 'A transaction you never made.',
                'brief': 'You did not expect a transaction alert.',
                'max_turns': 8,
                'flag_count': 6,
                'accent': 'lime',
              },
              'opening': 'KALAHARI BANK: Reverse now at https://kalahari-bank-secure.example.com/reverse',
              'turn': 0,
              'max_turns': 8,
              'status': 'active',
            }),
            201,
          );
        }
        if (path == '/api/rounds/round-mob/messages' &&
            request.method == 'POST') {
          return http.Response(
            jsonEncode({
              'round_id': 'round-mob',
              'reply': 'This is Agent Naledi. Confirm your OTP.',
              'turn': 1,
              'max_turns': 8,
              'status': 'active',
              'score': null,
              'limit_reached': false,
            }),
            200,
          );
        }
        if (path == '/api/rounds/round-mob/score' && request.method == 'POST') {
          return http.Response(
            jsonEncode({
              'score': 92,
              'grade': 'A',
              'verdict': 'Scam-proof.',
              'summary': '1 of 1 planted red flags spotted. 0 risky actions, 1 good move.',
              'flags': {'planted': [], 'spotted': [], 'missed': []},
              'actions': [
                {
                  'kind': 'refused',
                  'label': 'Refused the request',
                  'points': 8,
                  'source': 'code',
                },
              ],
              'breakdown': {
                'start': 100,
                'flag_bonus': 0,
                'flag_penalty': 0,
                'action_penalty': 0,
                'action_bonus': 8,
              },
              'advice': ['Nice work.'],
              'turn_count': 1,
            }),
            200,
          );
        }
        return http.Response('{}', 404);
      });

      final api = ApiClient(
        baseUrl: 'http://localhost:8080',
        client: mockClient,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: buildScamGymTheme(),
          home: HomeShell(
            api: api,
            baseUrl: '',
            epoch: 0,
            onServerChanged: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Pick a scam. Take a round.'), findsOneWidget);
      expect(find.text('Link'), findsOneWidget);
      expect(find.text('Message'), findsOneWidget);
      expect(find.text('Check a link'), findsNothing);
      await tester.ensureVisible(find.text('Start round'));
      await tester.tap(find.text('Start round'));
      await tester.pumpAndSettle();

      expect(find.text('Turn 0 / 8'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'This is a scam.');
      await tester.tap(find.text('Send'));
      await tester.pumpAndSettle();

      expect(find.text('Turn 1 / 8'), findsOneWidget);
      await tester.ensureVisible(find.text('Weigh in'));
      await tester.tap(find.text('Weigh in'));
      await tester.pumpAndSettle();

      expect(find.text('Refused the request'), findsOneWidget);
    },
  );

  testWidgets('LinkScreen checks a link, clears the field and checks another', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final mockClient = MockClient((request) async {
      if (request.url.path == '/api/check/link' && request.method == 'POST') {
        return http.Response(
          jsonEncode({
            'input':
                'http://kalahari-bank.example.com.verify-login.top/reverse',
            'normalized':
                'http://kalahari-bank.example.com.verify-login.top/reverse',
            'host': 'kalahari-bank.example.com.verify-login.top',
            'registrable_domain': 'verify-login.top',
            'score': 72,
            'verdict': 'high',
            'verdict_label': 'Likely phishing',
            'severity': 'high',
            'is_demo': false,
            'findings': [
              {
                'id': 'suspicious_tld',
                'label': 'High-risk domain ending',
                'detail': 'The address ends in a cheap TLD often used for scams.',
                'weight': 30,
                'severity': 'high',
              },
            ],
            'advice': ['Do not enter your password on this page.'],
            'not_checked': ['Who actually owns the domain.'],
          }),
          200,
        );
      }
      return http.Response('{}', 404);
    });

    final api = ApiClient(baseUrl: 'http://localhost:8080', client: mockClient);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildScamGymTheme(),
        home: Scaffold(body: LinkScreen(api: api)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'http://example.test');
    await tester.pump();
    expect(find.byType(ClearFieldButton), findsOneWidget);
    await tester.tap(find.byType(ClearFieldButton));
    await tester.pump();
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller?.text, isEmpty);

    await tester.enterText(
      find.byType(TextField),
      'http://kalahari-bank.example.com.verify-login.top/reverse',
    );
    await tester.tap(find.text('Check link'));
    await tester.pumpAndSettle();

    expect(find.text('Likely phishing'), findsNWidgets(2));
    expect(find.text('High-risk domain ending'), findsOneWidget);
    expect(find.text('What this check cannot see'), findsOneWidget);
    expect(find.text('Check another link'), findsOneWidget);
  });

  testWidgets('MessageScreen shows links and numbers from a report', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1100);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final mockClient = MockClient((request) async {
      if (request.url.path == '/api/check/message' &&
          request.method == 'POST') {
        return http.Response(
          jsonEncode({
            'input': 'Pay the R99 fee today.',
            'score': 81,
            'verdict': 'high',
            'verdict_label': 'Likely scam',
            'severity': 'high',
            'findings': [
              {
                'id': 'urgency',
                'label': 'Urgency',
                'detail': 'It pushes you to act today.',
                'weight': 20,
                'severity': 'high',
              },
            ],
            'links': [
              {
                'input': 'https://ubuntu-grants-pay.example.com/claim',
                'host': 'ubuntu-grants-pay.example.com',
                'score': 64,
                'verdict': 'high',
                'verdict_label': 'Likely phishing',
                'findings': [],
                'advice': [],
                'not_checked': [],
              },
            ],
            'phone_numbers': ['072 000 0199'],
            'advice': ['Do not pay the fee.'],
            'not_checked': ['Whether the number is really registered.'],
          }),
          200,
        );
      }
      return http.Response('{}', 404);
    });

    final api = ApiClient(baseUrl: 'http://localhost:8080', client: mockClient);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildScamGymTheme(),
        home: Scaffold(body: MessageScreen(api: api)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextField),
      'Pay the R99 fee today at https://ubuntu-grants-pay.example.com/claim',
    );
    await tester.tap(find.text('Check message'));
    await tester.pumpAndSettle();

    expect(find.text('Likely scam'), findsNWidgets(2));
    expect(find.text('Urgency'), findsOneWidget);
    expect(find.text('Links in the message'), findsOneWidget);
    expect(find.text('ubuntu-grants-pay.example.com'), findsOneWidget);
    expect(find.text('Numbers in the message'), findsOneWidget);
    expect(find.text('Check another message'), findsOneWidget);
  });
}

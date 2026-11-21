import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scamgym/models.dart';
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
        {'id': 'suspicious_tld', 'label': 'High-risk domain ending', 'detail': 'x', 'weight': 30},
      ],
    });

    expect(report.score, 55);
    expect(report.verdict, 'high');
    expect(report.findings, hasLength(1));
    expect(report.aiExplanation, isNull);
  });

  testWidgets('ScoreRing shows the score', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Center(child: ScoreRing(score: 80)))),
    );
    expect(find.text('80'), findsOneWidget);
    expect(find.text('/100'), findsOneWidget);
  });
}

// API models. Every parser is defensive: a missing field becomes a sensible
// default instead of a crash.

int _int(dynamic value, [int fallback = 0]) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

String _string(dynamic value, [String fallback = '']) =>
    value is String ? value : fallback;

bool _bool(dynamic value, [bool fallback = false]) =>
    value is bool ? value : fallback;

Map<String, dynamic> _map(dynamic value) =>
    value is Map<String, dynamic> ? value : <String, dynamic>{};

List<Map<String, dynamic>> _mapList(dynamic value) {
  if (value is! List) return const [];
  return value.whereType<Map<String, dynamic>>().toList(growable: false);
}

List<String> _stringList(dynamic value) {
  if (value is! List) return const [];
  return value.whereType<String>().toList(growable: false);
}

class Health {
  final bool ai;
  final String model;
  final int scenarios;
  final String version;

  const Health({
    required this.ai,
    required this.model,
    required this.scenarios,
    required this.version,
  });

  factory Health.fromJson(Map<String, dynamic> json) => Health(
    ai: _bool(json['ai']),
    model: _string(json['model'], 'gemini'),
    scenarios: _int(json['scenarios']),
    version: _string(json['version'], '0.1.0'),
  );
}

class Scenario {
  final String id;
  final String title;
  final String org;
  final String channel;
  final int difficulty;
  final String teaser;
  final String brief;
  final int maxTurns;
  final int flagCount;
  final String accent;

  const Scenario({
    required this.id,
    required this.title,
    required this.org,
    required this.channel,
    required this.difficulty,
    required this.teaser,
    required this.brief,
    required this.maxTurns,
    required this.flagCount,
    required this.accent,
  });

  factory Scenario.fromJson(Map<String, dynamic> json) => Scenario(
    id: _string(json['id']),
    title: _string(json['title'], 'Untitled scenario'),
    org: _string(json['org'], 'Fictional organisation'),
    channel: _string(json['channel'], 'SMS'),
    difficulty: _int(json['difficulty'], 1),
    teaser: _string(json['teaser']),
    brief: _string(json['brief']),
    maxTurns: _int(json['max_turns'], 8),
    flagCount: _int(json['flag_count']),
    accent: _string(json['accent'], 'lime'),
  );
}

class RoundStart {
  final String roundId;
  final Scenario scenario;
  final String opening;
  final int turn;
  final int maxTurns;
  final String status;

  const RoundStart({
    required this.roundId,
    required this.scenario,
    required this.opening,
    required this.turn,
    required this.maxTurns,
    required this.status,
  });

  factory RoundStart.fromJson(Map<String, dynamic> json) => RoundStart(
    roundId: _string(json['round_id']),
    scenario: Scenario.fromJson(_map(json['scenario'])),
    opening: _string(json['opening']),
    turn: _int(json['turn']),
    maxTurns: _int(json['max_turns'], 8),
    status: _string(json['status'], 'active'),
  );
}

class SendResult {
  final String reply;
  final int turn;
  final int maxTurns;
  final String status;
  final WeighIn? score;
  final bool limitReached;

  const SendResult({
    required this.reply,
    required this.turn,
    required this.maxTurns,
    required this.status,
    required this.score,
    required this.limitReached,
  });

  factory SendResult.fromJson(Map<String, dynamic> json) => SendResult(
    reply: _string(json['reply']),
    turn: _int(json['turn']),
    maxTurns: _int(json['max_turns'], 8),
    status: _string(json['status'], 'active'),
    score: json['score'] is Map<String, dynamic>
        ? WeighIn.fromJson(_map(json['score']))
        : null,
    limitReached: _bool(json['limit_reached']),
  );
}

class FlagInfo {
  final String id;
  final String label;
  final String explanation;
  final String severity;
  final bool spotted;

  const FlagInfo({
    required this.id,
    required this.label,
    required this.explanation,
    required this.severity,
    required this.spotted,
  });

  factory FlagInfo.fromJson(Map<String, dynamic> json) => FlagInfo(
    id: _string(json['id']),
    label: _string(json['label']),
    explanation: _string(json['explanation']),
    severity: _string(json['severity'], 'medium'),
    spotted: _bool(json['spotted']),
  );
}

class WeighInFlags {
  final List<FlagInfo> planted;
  final List<FlagInfo> spotted;
  final List<FlagInfo> missed;

  const WeighInFlags({
    required this.planted,
    required this.spotted,
    required this.missed,
  });

  factory WeighInFlags.fromJson(Map<String, dynamic> json) => WeighInFlags(
    planted: _mapList(json['planted']).map(FlagInfo.fromJson).toList(),
    spotted: _mapList(json['spotted']).map(FlagInfo.fromJson).toList(),
    missed: _mapList(json['missed']).map(FlagInfo.fromJson).toList(),
  );
}

class ActionInfo {
  final String kind;
  final String label;
  final int points;
  final String source;

  const ActionInfo({
    required this.kind,
    required this.label,
    required this.points,
    required this.source,
  });

  factory ActionInfo.fromJson(Map<String, dynamic> json) => ActionInfo(
    kind: _string(json['kind']),
    label: _string(json['label']),
    points: _int(json['points']),
    source: _string(json['source']),
  );
}

class ScoreBreakdown {
  final int start;
  final int flagBonus;
  final int flagPenalty;
  final int actionPenalty;
  final int actionBonus;

  const ScoreBreakdown({
    required this.start,
    required this.flagBonus,
    required this.flagPenalty,
    required this.actionPenalty,
    required this.actionBonus,
  });

  factory ScoreBreakdown.fromJson(Map<String, dynamic> json) => ScoreBreakdown(
    start: _int(json['start'], 100),
    flagBonus: _int(json['flag_bonus']),
    flagPenalty: _int(json['flag_penalty']),
    actionPenalty: _int(json['action_penalty']),
    actionBonus: _int(json['action_bonus']),
  );
}

class WeighIn {
  final int score;
  final String grade;
  final String verdict;
  final String summary;
  final WeighInFlags flags;
  final List<ActionInfo> actions;
  final ScoreBreakdown breakdown;
  final List<String> advice;
  final int turnCount;

  const WeighIn({
    required this.score,
    required this.grade,
    required this.verdict,
    required this.summary,
    required this.flags,
    required this.actions,
    required this.breakdown,
    required this.advice,
    required this.turnCount,
  });

  factory WeighIn.fromJson(Map<String, dynamic> json) => WeighIn(
    score: _int(json['score']),
    grade: _string(json['grade'], '—'),
    verdict: _string(json['verdict']),
    summary: _string(json['summary']),
    flags: WeighInFlags.fromJson(_map(json['flags'])),
    actions: _mapList(json['actions']).map(ActionInfo.fromJson).toList(),
    breakdown: ScoreBreakdown.fromJson(_map(json['breakdown'])),
    advice: _stringList(json['advice']),
    turnCount: _int(json['turn_count']),
  );
}

class Finding {
  final String id;
  final String label;
  final String detail;
  final int weight;
  final String severity;

  const Finding({
    required this.id,
    required this.label,
    required this.detail,
    required this.weight,
    required this.severity,
  });

  factory Finding.fromJson(Map<String, dynamic> json) => Finding(
    id: _string(json['id']),
    label: _string(json['label']),
    detail: _string(json['detail']),
    weight: _int(json['weight']),
    severity: _string(json['severity'], 'low'),
  );
}

class LinkReport {
  final String input;
  final String normalized;
  final String host;
  final String registrableDomain;
  final int score;
  final String verdict;
  final String verdictLabel;
  final String severity;
  final bool isDemo;
  final List<Finding> findings;
  final List<String> advice;
  final List<String> notChecked;
  final String? aiExplanation;

  const LinkReport({
    required this.input,
    required this.normalized,
    required this.host,
    required this.registrableDomain,
    required this.score,
    required this.verdict,
    required this.verdictLabel,
    required this.severity,
    required this.isDemo,
    required this.findings,
    required this.advice,
    required this.notChecked,
    required this.aiExplanation,
  });

  factory LinkReport.fromJson(Map<String, dynamic> json) => LinkReport(
    input: _string(json['input']),
    normalized: _string(json['normalized']),
    host: _string(json['host']),
    registrableDomain: _string(json['registrable_domain']),
    score: _int(json['score']),
    verdict: _string(json['verdict'], 'low'),
    verdictLabel: _string(json['verdict_label']),
    severity: _string(json['severity'], 'low'),
    isDemo: _bool(json['is_demo']),
    findings: _mapList(json['findings']).map(Finding.fromJson).toList(),
    advice: _stringList(json['advice']),
    notChecked: _stringList(json['not_checked']),
    aiExplanation: json['ai_explanation'] is String
        ? json['ai_explanation'] as String
        : null,
  );
}

class MessageReport {
  final String input;
  final int score;
  final String verdict;
  final String verdictLabel;
  final String severity;
  final List<Finding> findings;
  final List<LinkReport> links;
  final List<String> phoneNumbers;
  final List<String> advice;
  final List<String> notChecked;
  final String? aiExplanation;

  const MessageReport({
    required this.input,
    required this.score,
    required this.verdict,
    required this.verdictLabel,
    required this.severity,
    required this.findings,
    required this.links,
    required this.phoneNumbers,
    required this.advice,
    required this.notChecked,
    required this.aiExplanation,
  });

  factory MessageReport.fromJson(Map<String, dynamic> json) => MessageReport(
    input: _string(json['input']),
    score: _int(json['score']),
    verdict: _string(json['verdict'], 'low'),
    verdictLabel: _string(json['verdict_label']),
    severity: _string(json['severity'], 'low'),
    findings: _mapList(json['findings']).map(Finding.fromJson).toList(),
    links: _mapList(json['links']).map(LinkReport.fromJson).toList(),
    phoneNumbers: _stringList(json['phone_numbers']),
    advice: _stringList(json['advice']),
    notChecked: _stringList(json['not_checked']),
    aiExplanation: json['ai_explanation'] is String
        ? json['ai_explanation'] as String
        : null,
  );
}

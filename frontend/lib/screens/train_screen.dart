import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../api.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/app_footer.dart';
import '../widgets/common.dart';

class TrainScreen extends StatefulWidget {
  final ApiClient api;

  const TrainScreen({super.key, required this.api});

  @override
  State<TrainScreen> createState() => _TrainScreenState();
}

class _ChatEntry {
  final String role; // scammer | user | system
  final String text;

  const _ChatEntry(this.role, this.text);
}

class _TrainScreenState extends State<TrainScreen> {
  bool _loading = true;
  String? _error;
  List<Scenario> _scenarios = const [];
  Health? _health;

  RoundStart? _round;
  final List<_ChatEntry> _chat = [];
  final TextEditingController _input = TextEditingController();
  final FocusNode _inputFocus = FocusNode();
  final ScrollController _scroll = ScrollController();
  final GlobalKey _weighInKey = GlobalKey();

  bool _sending = false;
  bool _starting = false;
  String? _startingId;
  bool _weighing = false;
  WeighIn? _weighIn;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _input.dispose();
    _inputFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final scenarios = await widget.api.scenarios();
      final health = await widget.api.health();
      if (!mounted) return;
      setState(() {
        _scenarios = scenarios;
        _health = health;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  void _snack(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: error ? const Color(0xFF2A1616) : AppColors.panel3,
        ),
      );
  }

  Future<void> _start(Scenario scenario) async {
    if (_starting) return;
    if (_health?.ai == false) {
      _snack('Gemini is not configured, so training is offline. The checkers still work.', error: true);
      return;
    }
    setState(() {
      _starting = true;
      _startingId = scenario.id;
    });
    try {
      final round = await widget.api.startRound(scenario.id);
      if (!mounted) return;
      setState(() {
        _round = round;
        _chat
          ..clear()
          ..add(_ChatEntry('scammer', round.opening));
        _weighIn = null;
        _starting = false;
        _startingId = null;
      });
      _scrollChat();
      _inputFocus.requestFocus();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _starting = false;
        _startingId = null;
      });
      _snack(error.toString(), error: true);
    }
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    final round = _round;
    if (text.isEmpty || _sending || round == null || round.status != 'active') return;

    _input.clear();
    final entry = _ChatEntry('user', text);
    setState(() {
      _sending = true;
      _chat.add(entry);
    });
    _scrollChat();

    try {
      final result = await widget.api.sendMessage(round.roundId, text);
      if (!mounted) return;
      setState(() {
        _chat.add(_ChatEntry('scammer', result.reply));
        _round = RoundStart(
          roundId: round.roundId,
          scenario: round.scenario,
          opening: round.opening,
          turn: result.turn,
          maxTurns: result.maxTurns,
          status: result.status,
        );
        if (result.score != null) _weighIn = result.score;
        _sending = false;
      });
      _scrollChat();
      if (result.limitReached) {
        _snack('Turn limit reached. Weigh in to see your score.');
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _chat.remove(entry);
        _input.text = text;
        _sending = false;
      });
      _snack(error.toString(), error: true);
      _inputFocus.requestFocus();
    }
  }

  Future<void> _weigh() async {
    final round = _round;
    if (round == null || _weighing) return;
    setState(() => _weighing = true);
    try {
      final score = await widget.api.scoreRound(round.roundId);
      if (!mounted) return;
      setState(() {
        _weighIn = score;
        _round = RoundStart(
          roundId: round.roundId,
          scenario: round.scenario,
          opening: round.opening,
          turn: round.turn,
          maxTurns: round.maxTurns,
          status: 'scored',
        );
        _weighing = false;
      });
      _scrollToWeighIn();
    } catch (error) {
      if (!mounted) return;
      setState(() => _weighing = false);
      _snack(error.toString(), error: true);
    }
  }

  void _reset() {
    setState(() {
      _round = null;
      _chat.clear();
      _weighIn = null;
      _input.clear();
    });
  }

  Future<void> _leave() async {
    if (_round == null) return;
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.panel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppColors.line),
        ),
        title: const Text('Leave this round?'),
        content: const Text(
          'Your score will be lost. The server drops the round when it expires.',
          style: TextStyle(color: AppColors.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: TextButton.styleFrom(foregroundColor: AppColors.muted),
            child: const Text('Stay'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: primaryButtonStyle,
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (leave == true) _reset();
  }

  Future<void> _openLink(String url) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.panel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppColors.line),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Eyebrow('Simulated link'),
            SizedBox(height: 8),
            Text('This is where people get caught.'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.line),
              ),
              child: Text(
                url,
                style: kMono.copyWith(color: AppColors.amber, fontSize: 11.5),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'In a real scam, clicking could install malware or open a fake login page. '
              'ScamGym records the click for your score, but never opens the link.',
              style: TextStyle(color: AppColors.muted, fontSize: 13, height: 1.5),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: TextButton.styleFrom(foregroundColor: AppColors.muted),
            child: const Text('Back out'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: dangerButtonStyle,
            child: const Text("I'd click it"),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    final round = _round;
    if (round == null || round.status != 'active') {
      _snack('This round is finished, so the click cannot be scored.');
      return;
    }
    try {
      await widget.api.recordLinkClick(round.roundId, url);
      if (!mounted) return;
      setState(() {
        _chat.add(const _ChatEntry('system', 'You clicked the link. The scorer noted it.'));
      });
      _scrollChat();
    } catch (error) {
      _snack(error.toString(), error: true);
    }
  }

  void _scrollChat() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    });
  }

  void _scrollToWeighIn() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _weighInKey.currentContext;
      if (context == null) return;
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
        alignment: 0.04,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = math.min(constraints.maxWidth, 1120.0);
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_loading)
                    _loadingView()
                  else if (_error != null)
                    _errorView()
                  else if (_round == null)
                    ..._lobby()
                  else
                    ..._roundView(),
                  const AppFooter(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _loadingView() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 90),
      child: Center(child: LoadingLine('Loading the gym…')),
    );
  }

  Widget _errorView() {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: SectionCard(
        title: 'Could not load the gym',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _error ?? 'Unknown error',
              style: const TextStyle(color: AppColors.muted, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: _load,
              style: primaryButtonStyle,
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _lobby() {
    return [
      _panelHead(),
      const SizedBox(height: 16),
      _howCard(),
      const SizedBox(height: 22),
      if (_health?.ai == false)
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: SectionCard(
            border: Border.all(color: AppColors.amber.withValues(alpha: 0.35)),
            color: AppColors.amber.withValues(alpha: 0.055),
            child: const Text(
              'Gemini is not configured on this server, so the live scammer is offline. '
              'The link and message checkers still work because their verdicts are pure code.',
              style: TextStyle(color: AppColors.amber, fontSize: 12.5, height: 1.5),
            ),
          ),
        ),
      _scenarioGrid(),
    ];
  }

  Widget _panelHead() {
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Eyebrow('The gym'),
        const SizedBox(height: 6),
        Text('Pick a scam. Take a round.', style: Theme.of(context).textTheme.headlineMedium),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final pill = _healthPill();
        if (constraints.maxWidth >= 640) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: title),
              const SizedBox(width: 16),
              pill,
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [title, const SizedBox(height: 10), pill],
        );
      },
    );
  }

  Widget _healthPill() {
    final health = _health;
    if (health == null) {
      return const Pill(label: 'Checking the coach…', color: AppColors.muted);
    }
    if (health.ai) {
      return Pill(label: 'Coach online · ${health.model}', color: AppColors.lime);
    }
    return const Pill(label: 'Gemini offline · checkers still work', color: AppColors.red);
  }

  Widget _howCard() {
    final steps = [
      const _HowStep(
        number: '01',
        title: 'The AI writes the scam.',
        body:
            'Gemini plays a scammer from a fictional scenario and plants a known set of red flags.',
      ),
      const _HowStep(
        number: '02',
        title: 'You reply like it is real.',
        body:
            'Refuse, question, verify, or fall for it. Nothing leaves this app and no real money moves.',
      ),
      const _HowStep(
        number: '03',
        title: 'Code does the weigh-in.',
        body:
            "Your words and clicks are scored by deterministic Python, never by the model's opinion.",
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 760;
        return Container(
          decoration: BoxDecoration(
            color: AppColors.lineSoft,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.line),
          ),
          clipBehavior: Clip.antiAlias,
          child: wide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < steps.length; i++) ...[
                      if (i > 0) const SizedBox(width: 1),
                      Expanded(
                        child: Container(color: AppColors.panel2, child: steps[i]),
                      ),
                    ],
                  ],
                )
              : Column(
                  children: [
                    for (var i = 0; i < steps.length; i++) ...[
                      if (i > 0) const Divider(height: 1),
                      Container(color: AppColors.panel2, child: steps[i]),
                    ],
                  ],
                ),
        );
      },
    );
  }

  Widget _scenarioGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1000
            ? 3
            : (constraints.maxWidth >= 680 ? 2 : 1);
        final width = (constraints.maxWidth - (columns - 1) * 14) / columns;
        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            for (final scenario in _scenarios)
              SizedBox(
                width: width,
                child: _ScenarioCard(
                  scenario: scenario,
                  disabled: _health?.ai == false,
                  starting: _starting && _startingId == scenario.id,
                  onStart: () => _start(scenario),
                ),
              ),
          ],
        );
      },
    );
  }

  List<Widget> _roundView() {
    final round = _round!;
    final finished = round.status != 'active';
    return [
      _roundHead(round),
      const SizedBox(height: 12),
      _chatCard(round, finished),
      if (finished && _weighIn == null)
        Padding(
          padding: const EdgeInsets.only(top: 14),
          child: SectionCard(
            border: Border.all(color: AppColors.amber.withValues(alpha: 0.35)),
            color: AppColors.amber.withValues(alpha: 0.055),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'This round is over. Weigh in to see what the scammer planted and what it cost you.',
                    style: TextStyle(color: AppColors.amber, fontSize: 12.5, height: 1.5),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: _weighing ? null : _weigh,
                  style: primaryButtonStyle,
                  child: _weighing
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Weigh in'),
                ),
              ],
            ),
          ),
        ),
      if (_weighIn != null) ...[
        const SizedBox(height: 18),
        _weighInView(_weighIn!),
      ],
    ];
  }

  Widget _roundHead(RoundStart round) {
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Eyebrow('${round.scenario.org} · ${round.scenario.channel}'),
        const SizedBox(height: 5),
        Text(round.scenario.title, style: Theme.of(context).textTheme.headlineSmall),
      ],
    );

    final actions = Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.text.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            'Turn ${round.turn} / ${round.maxTurns}',
            style: kMono.copyWith(color: AppColors.muted, fontSize: 10.5),
          ),
        ),
        OutlinedButton(
          onPressed: _weighing ? null : _weigh,
          style: secondaryButtonStyle,
          child: _weighing
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Weigh in'),
        ),
        OutlinedButton(
          onPressed: _leave,
          style: secondaryButtonStyle,
          child: const Text('Leave'),
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 700) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: title),
              const SizedBox(width: 14),
              actions,
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [title, const SizedBox(height: 10), actions],
        );
      },
    );
  }

  Widget _chatCard(RoundStart round, bool finished) {
    final chatHeight = (MediaQuery.sizeOf(context).height * 0.5).clamp(280.0, 520.0).toDouble();
    final canSend = !finished && !_sending;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0x08B7F36B),
              border: Border(bottom: BorderSide(color: AppColors.lineSoft)),
            ),
            child: Text(
              round.scenario.brief,
              style: const TextStyle(color: AppColors.muted, fontSize: 12.5, height: 1.45),
            ),
          ),
          SizedBox(
            height: chatHeight,
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.all(16),
              itemCount: _chat.length + (_sending ? 1 : 0),
              itemBuilder: (context, index) {
                if (index >= _chat.length) {
                  return const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: _TypingBubble(),
                  );
                }
                final entry = _chat[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _Bubble(entry: entry, onLink: _openLink),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
            decoration: const BoxDecoration(
              color: AppColors.panel2,
              border: Border(top: BorderSide(color: AppColors.line)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    focusNode: _inputFocus,
                    enabled: canSend,
                    minLines: 1,
                    maxLines: 4,
                    maxLength: 1200,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    style: const TextStyle(fontSize: 14),
                    decoration: scamInput(hint: 'Reply as if this were real…').copyWith(
                      counterText: '',
                      fillColor: AppColors.bg,
                    ),
                  ),
                ),
                const SizedBox(width: 9),
                FilledButton(
                  onPressed: canSend ? _send : null,
                  style: primaryButtonStyle,
                  child: _sending
                      ? const SizedBox(
                          width: 15,
                          height: 15,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Send'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text(
              'Never type real card numbers, PINs, OTPs or ID numbers. Use made-up answers.',
              style: kMono.copyWith(color: AppColors.muted2, fontSize: 9.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _weighInView(WeighIn score) {
    return Container(
      key: _weighInKey,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
        gradient: RadialGradient(
          center: const Alignment(-0.8, -1),
          radius: 1.1,
          colors: [AppColors.lime.withValues(alpha: 0.06), AppColors.panel],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 22,
            runSpacing: 16,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ScoreRing(score: score.score),
              SizedBox(
                width: math.min(MediaQuery.sizeOf(context).width - 80, 640.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Eyebrow('Weigh-in'),
                    const SizedBox(height: 4),
                    Text(
                      score.grade,
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                            color: scoreColor(score.score),
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      score.verdict,
                      style: const TextStyle(color: AppColors.muted, fontSize: 13.5, height: 1.45),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      score.summary,
                      style: kMono.copyWith(color: AppColors.muted2, fontSize: 10),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 760 ? 2 : 1;
              final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(width: width, child: _flagsCard(score)),
                  SizedBox(width: width, child: _actionsCard(score)),
                  SizedBox(width: width, child: _breakdownCard(score)),
                  SizedBox(width: width, child: _adviceCard(score)),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton(
                onPressed: () => _start(_round!.scenario),
                style: primaryButtonStyle,
                child: const Text('Run it again'),
              ),
              OutlinedButton(
                onPressed: _reset,
                style: secondaryButtonStyle,
                child: const Text('Pick another scam'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _flagsCard(WeighIn score) {
    final flags = score.flags.planted;
    return SectionCard(
      title: 'Red flags',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (flags.isEmpty)
            const EmptyNote('No red flags were recorded for this round.')
          else
            for (final flag in flags) _FlagRow(flag: flag),
        ],
      ),
    );
  }

  Widget _actionsCard(WeighIn score) {
    return SectionCard(
      title: 'Your actions',
      child: score.actions.isEmpty
          ? const EmptyNote('No risky actions recorded. Clean round.')
          : Column(
              children: [
                for (final action in score.actions)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            action.label,
                            style: const TextStyle(fontSize: 12.5, height: 1.4),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          action.points >= 0 ? '+${action.points}' : '${action.points}',
                          style: kMono.copyWith(
                            color: action.points >= 0 ? AppColors.lime : AppColors.red,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _breakdownCard(WeighIn score) {
    final breakdown = score.breakdown;
    return SectionCard(
      title: 'How the score was built',
      child: Column(
        children: [
          _BreakdownRow(label: 'Start', value: '${breakdown.start}'),
          if (breakdown.flagBonus != 0)
            _BreakdownRow(label: 'Flags spotted', value: '+${breakdown.flagBonus}'),
          if (breakdown.flagPenalty != 0)
            _BreakdownRow(label: 'Flags missed', value: '${breakdown.flagPenalty}'),
          if (breakdown.actionPenalty != 0)
            _BreakdownRow(label: 'Risky actions', value: '${breakdown.actionPenalty}'),
          if (breakdown.actionBonus != 0)
            _BreakdownRow(label: 'Good moves', value: '+${breakdown.actionBonus}'),
          const SizedBox(height: 6),
          const Divider(),
          const SizedBox(height: 6),
          _BreakdownRow(label: 'Final', value: '${score.score}', total: true),
        ],
      ),
    );
  }

  Widget _adviceCard(WeighIn score) {
    return SectionCard(
      title: 'What to do next time',
      child: AdviceList(items: score.advice),
    );
  }
}

class _HowStep extends StatelessWidget {
  final String number;
  final String title;
  final String body;

  const _HowStep({required this.number, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            number,
            style: kMonoSmall.copyWith(color: AppColors.limeDim, fontSize: 10),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(
                  body,
                  style: const TextStyle(color: AppColors.muted, fontSize: 11.5, height: 1.45),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScenarioCard extends StatelessWidget {
  final Scenario scenario;
  final bool disabled;
  final bool starting;
  final VoidCallback onStart;

  const _ScenarioCard({
    required this.scenario,
    required this.disabled,
    required this.starting,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    final accent = accentColor(scenario.accent);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: disabled || starting ? null : onStart,
        child: Container(
          constraints: const BoxConstraints(minHeight: 224),
          decoration: BoxDecoration(
            color: AppColors.panel,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.line),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(height: 3, color: accent.withValues(alpha: 0.9)),
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.text.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            scenario.channel.toUpperCase(),
                            style: kMono.copyWith(
                              color: AppColors.muted,
                              fontSize: 8.5,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        const Spacer(),
                        for (var i = 0; i < 3; i++)
                          Container(
                            width: 6,
                            height: 6,
                            margin: const EdgeInsets.only(left: 4),
                            decoration: BoxDecoration(
                              color: i < scenario.difficulty ? accent : AppColors.line,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      scenario.title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 7),
                    Text(
                      scenario.teaser,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12.5,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${scenario.flagCount} red flags planted',
                            style: kMono.copyWith(
                              color: AppColors.muted2,
                              fontSize: 9.5,
                            ),
                          ),
                        ),
                        FilledButton(
                          onPressed: disabled || starting ? null : onStart,
                          style: primaryButtonStyle.copyWith(
                            padding: const WidgetStatePropertyAll(
                              EdgeInsets.symmetric(horizontal: 13, vertical: 10),
                            ),
                          ),
                          child: starting
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Text(disabled ? 'AI offline' : 'Start round'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final _ChatEntry entry;
  final ValueChanged<String> onLink;

  const _Bubble({required this.entry, required this.onLink});

  static final RegExp _urlPattern = RegExp(
    r'''https?://[^\s<>"']+''',
    caseSensitive: false,
  );

  List<String> _urls(String text) {
    final values = <String>{};
    for (final match in _urlPattern.allMatches(text)) {
      final value = match.group(0)?.replaceFirst(RegExp(r'[.,;:!?)\]}]+$'), '') ?? '';
      if (value.isNotEmpty) values.add(value);
    }
    return values.toList(growable: false);
  }

  String _host(String url) {
    final uri = Uri.tryParse(url);
    return uri != null && uri.host.isNotEmpty ? uri.host : url;
  }

  @override
  Widget build(BuildContext context) {
    if (entry.role == 'system') {
      return Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.line),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            entry.text,
            textAlign: TextAlign.center,
            style: kMono.copyWith(color: AppColors.muted2, fontSize: 9.5),
          ),
        ),
      );
    }

    final isUser = entry.role == 'user';
    final urls = isUser ? const <String>[] : _urls(entry.text);

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: math.min(MediaQuery.sizeOf(context).width * 0.82, 620.0),
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(13, 10, 13, 10),
          decoration: BoxDecoration(
            color: isUser ? AppColors.lime.withValues(alpha: 0.12) : AppColors.panel2,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isUser ? 16 : 5),
              bottomRight: Radius.circular(isUser ? 5 : 16),
            ),
            border: Border.all(
              color: isUser
                  ? AppColors.lime.withValues(alpha: 0.32)
                  : AppColors.line,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isUser ? 'YOU' : 'SCAMMER',
                style: kMono.copyWith(
                  color: isUser
                      ? AppColors.lime.withValues(alpha: 0.65)
                      : AppColors.muted2,
                  fontSize: 8.5,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 4),
              SelectableText(
                entry.text,
                style: const TextStyle(fontSize: 13.5, height: 1.5),
              ),
              if (urls.isNotEmpty) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    for (final url in urls)
                      TextButton.icon(
                        onPressed: () => onLink(url),
                        icon: const Icon(Icons.open_in_new, size: 13),
                        label: Text(_host(url)),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.amber,
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          textStyle: kMono.copyWith(fontSize: 10.5),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return const Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.only(top: 2),
        child: LoadingLine('The scammer is typing…'),
      ),
    );
  }
}

class _FlagRow extends StatelessWidget {
  final FlagInfo flag;

  const _FlagRow({required this.flag});

  @override
  Widget build(BuildContext context) {
    final color = flag.spotted ? AppColors.lime : AppColors.red;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 18,
            height: 18,
            margin: const EdgeInsets.only(top: 1),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(
              flag.spotted ? Icons.check : Icons.close,
              size: 12,
              color: color,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        flag.label,
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.text.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        flag.severity.toUpperCase(),
                        style: kMono.copyWith(
                          color: AppColors.muted2,
                          fontSize: 7.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  flag.explanation,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 11.5,
                    height: 1.42,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  final String label;
  final String value;
  final bool total;

  const _BreakdownRow({required this.label, required this.value, this.total = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: total ? AppColors.text : AppColors.muted,
                fontSize: 12,
                fontWeight: total ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ),
          Text(
            value,
            style: kMono.copyWith(
              color: total ? AppColors.text : AppColors.muted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

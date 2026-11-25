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
    showScamSnackBar(context, message, error: error);
  }

  Future<void> _start(Scenario scenario) async {
    if (_starting) return;
    if (_health?.ai == false) {
      _snack(
        'Gemini is not configured, so training is offline. The checkers still work.',
        error: true,
      );
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
    if (text.isEmpty || _sending || round == null || round.status != 'active') {
      return;
    }

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
      if (result.score != null) {
        _scrollToWeighIn();
      } else if (result.limitReached) {
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
    if (round == null || _weighing || _weighIn != null) return;
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
        title: const Text('Leave this round?'),
        content: const Text(
          'Your score will be lost. The server drops the round when it expires.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Stay'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: dangerButtonStyle,
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (leave == true) {
      final roundId = _round?.roundId;
      _reset();
      if (roundId != null && roundId.isNotEmpty) {
        widget.api.deleteRound(roundId).catchError((_) {});
      }
    }
  }

  Future<void> _openLink(String url) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
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
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.zero,
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Text(
                url,
                style: kMono.copyWith(
                  color: AppColors.supportWarning,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'In a real scam, clicking could install malware or open a fake login page. '
              'ScamGym records the click for your score, but never opens the link.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
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
        _chat.add(
          const _ChatEntry(
            'system',
            'You clicked the link. The scorer noted it.',
          ),
        );
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
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
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
      child: InlineNotice(
        kind: 'error',
        title: 'Could not load the gym',
        message: _error ?? 'Unknown error',
        action: FilledButton(onPressed: _load, child: const Text('Try again')),
      ),
    );
  }

  List<Widget> _lobby() {
    return [
      _panelHead(),
      const SizedBox(height: 24),
      _howCard(),
      const SizedBox(height: 32),
      if (_health?.ai == false)
        const Padding(
          padding: EdgeInsets.only(bottom: 24),
          child: InlineNotice(
            kind: 'warning',
            title: 'Gemini is offline',
            message:
                'Gemini is not configured on this server, so the live scammer is offline. '
                'The link and message checkers still work because their verdicts are pure code.',
          ),
        ),
      _scenarioGridOrEmpty(),
    ];
  }

  Widget _scenarioGridOrEmpty() {
    if (_scenarios.isEmpty) {
      return const EmptyNote(
        'No scenarios are available on this server yet. Check the server address, '
        'or try again once the backend is running.',
      );
    }
    return _scenarioGrid();
  }

  Widget _panelHead() {
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Eyebrow('The gym'),
        const SizedBox(height: 8),
        Text(
          'Pick a scam. Take a round.',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final pill = Semantics(
          container: true,
          liveRegion: true,
          child: _healthPill(),
        );
        if (constraints.maxWidth >= 640) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: title),
              const SizedBox(width: 16),
              pill,
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [title, const SizedBox(height: 12), pill],
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
      return Pill(
        label: 'Coach online · ${health.model}',
        color: AppColors.lime,
      );
    }
    return const Pill(
      label: 'Gemini offline · checkers still work',
      color: AppColors.red,
    );
  }

  Widget _howCard() {
    final steps = [
      const _HowStep(
        number: '01',
        title: 'The AI writes the scam.',
        body: 'Gemini plays a scammer from a fictional scenario and plants a known set of red flags.',
      ),
      const _HowStep(
        number: '02',
        title: 'You reply like it is real.',
        body: 'Refuse, question, verify, or fall for it. Nothing leaves this app and no real money moves.',
      ),
      const _HowStep(
        number: '03',
        title: 'Code does the weigh-in.',
        body: "Your words and clicks are scored by deterministic Python, never by the model's opinion.",
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 760;
        return Container(
          decoration: BoxDecoration(
            color: AppColors.layer,
            borderRadius: BorderRadius.zero,
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: wide
              ? IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < steps.length; i++) ...[
                        if (i > 0)
                          Container(width: 1, color: AppColors.borderSubtle),
                        Expanded(child: steps[i]),
                      ],
                    ],
                  ),
                )
              : Column(
                  children: [
                    for (var i = 0; i < steps.length; i++) ...[
                      if (i > 0)
                        const Divider(height: 1, color: AppColors.borderSubtle),
                      steps[i],
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
        final width = (constraints.maxWidth - (columns - 1) * 16) / columns;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
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
          padding: const EdgeInsets.only(top: 16),
          child: InlineNotice(
            kind: 'warning',
            title: 'This round is over',
            message: 'Weigh in to see what the scammer planted and what it cost you.',
            action: FilledButton(
              onPressed: _weighing ? null : _weigh,
              child: _weighing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Weigh in'),
            ),
          ),
        ),
      if (_weighIn != null) ...[
        const SizedBox(height: 24),
        _weighInView(_weighIn!),
      ],
    ];
  }

  Widget _roundHead(RoundStart round) {
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Eyebrow('${round.scenario.org} · ${round.scenario.channel}'),
        const SizedBox(height: 8),
        Semantics(
          header: true,
          child: Text(
            round.scenario.title,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ),
      ],
    );

    final actions = Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Pill(
          label: 'Turn ${round.turn} / ${round.maxTurns}',
          color: AppColors.textHelper,
        ),
        if (_weighIn == null)
          OutlinedButton(
            onPressed: _weighing ? null : _weigh,
            child: _weighing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Weigh in'),
          )
        else
          const Pill(label: 'Scored', color: AppColors.supportSuccess),
        OutlinedButton(onPressed: _leave, child: const Text('Leave')),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 700) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: title),
              const SizedBox(width: 16),
              actions,
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [title, const SizedBox(height: 16), actions],
        );
      },
    );
  }

  Widget _chatCard(RoundStart round, bool finished) {
    final chatHeight = (MediaQuery.sizeOf(context).height * 0.5)
        .clamp(280.0, 520.0)
        .toDouble();
    final canSend = !finished && !_sending;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.layer,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: AppColors.borderSubtle),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: AppColors.layer2,
              border: Border(bottom: BorderSide(color: AppColors.borderSubtle)),
            ),
            child: Text(
              round.scenario.brief,
              style: const TextStyle(
                fontFamily: 'IBMPlexSans',
                color: AppColors.textSecondary,
                fontSize: 14,
                height: 1.43,
              ),
            ),
          ),
          SizedBox(
            height: chatHeight,
            child: ColoredBox(
              color: AppColors.background,
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
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _Bubble(entry: entry, onLink: _openLink),
                  );
                },
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            decoration: const BoxDecoration(
              color: AppColors.layer,
              border: Border(top: BorderSide(color: AppColors.borderSubtle)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Semantics(
                    label: 'Your reply to the scammer',
                    child: TextField(
                      controller: _input,
                      focusNode: _inputFocus,
                      enabled: canSend,
                      minLines: 1,
                      maxLines: 4,
                      maxLength: 1200,
                      keyboardType: TextInputType.text,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      style: const TextStyle(
                        fontFamily: 'IBMPlexSans',
                        fontSize: 14,
                        height: 1.43,
                        color: AppColors.textPrimary,
                      ),
                      decoration:
                          scamInput(hint: 'Reply as if this were real…')
                              .copyWith(
                                counterText: '',
                                fillColor: AppColors.background,
                              ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                FilledButton(
                  onPressed: canSend ? _send : null,
                  child: _sending
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Send'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline,
                  size: 16,
                  color: AppColors.textHelper,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Never type real card numbers, PINs, OTPs or ID numbers. Use made-up answers.',
                    style: kMono.copyWith(
                      color: AppColors.textHelper,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _weighInView(WeighIn score) {
    final total = score.flags.planted.length;
    final spotted = score.flags.planted.where((flag) => flag.spotted).length;
    return Container(
      key: _weighInKey,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.layer,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            container: true,
            liveRegion: true,
            child: Wrap(
              spacing: 32,
              runSpacing: 24,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ScoreRing(score: score.score),
                SizedBox(
                  width: math.min(
                    MediaQuery.sizeOf(context).width - 80,
                    640.0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Eyebrow('Weigh-in'),
                      const SizedBox(height: 8),
                      Text(
                        score.grade,
                        style: Theme.of(context).textTheme.displaySmall
                            ?.copyWith(color: scoreColor(score.score)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        score.verdict,
                        style: const TextStyle(
                          fontFamily: 'IBMPlexSans',
                          color: AppColors.textSecondary,
                          fontSize: 16,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        score.summary,
                        style: kMono.copyWith(
                          color: AppColors.textHelper,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Pill(
                            label:
                                '$spotted of $total red flag${total == 1 ? '' : 's'} spotted',
                            color: total == 0
                                ? AppColors.textHelper
                                : (spotted == total
                                      ? AppColors.supportSuccess
                                      : AppColors.supportWarning),
                          ),
                          Pill(
                            label:
                                '${score.turnCount} turn${score.turnCount == 1 ? '' : 's'}',
                            color: AppColors.textHelper,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 760 ? 2 : 1;
              final width =
                  (constraints.maxWidth - (columns - 1) * 16) / columns;
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  SizedBox(width: width, child: _flagsCard(score)),
                  SizedBox(width: width, child: _actionsCard(score)),
                  SizedBox(width: width, child: _breakdownCard(score)),
                  SizedBox(width: width, child: _adviceCard(score)),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: [
              FilledButton(
                onPressed: () => _start(_round!.scenario),
                child: const Text('Run it again'),
              ),
              OutlinedButton(
                onPressed: _reset,
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
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: AppColors.borderSubtle),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            action.label,
                            style: const TextStyle(
                              fontFamily: 'IBMPlexSans',
                              fontSize: 14,
                              height: 1.43,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          action.points >= 0
                              ? '+${action.points}'
                              : '${action.points}',
                          style: kMono.copyWith(
                            color: action.points >= 0
                                ? AppColors.lime
                                : AppColors.red,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
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
            _BreakdownRow(
              label: 'Flags spotted',
              value: '+${breakdown.flagBonus}',
            ),
          if (breakdown.flagPenalty != 0)
            _BreakdownRow(
              label: 'Flags missed',
              value: '${breakdown.flagPenalty}',
            ),
          if (breakdown.actionPenalty != 0)
            _BreakdownRow(
              label: 'Risky actions',
              value: '${breakdown.actionPenalty}',
            ),
          if (breakdown.actionBonus != 0)
            _BreakdownRow(
              label: 'Good moves',
              value: '+${breakdown.actionBonus}',
            ),
          const SizedBox(height: 8),
          const Divider(),
          const SizedBox(height: 8),
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

  const _HowStep({
    required this.number,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            number,
            style: kMono.copyWith(
              color: AppColors.interactive,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'IBMPlexSans',
                      fontSize: 14,
                      height: 1.43,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: const TextStyle(
                    fontFamily: 'IBMPlexSans',
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    height: 1.43,
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

class _ScenarioCard extends StatefulWidget {
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
  State<_ScenarioCard> createState() => _ScenarioCardState();
}

class _ScenarioCardState extends State<_ScenarioCard> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final scenario = widget.scenario;
    final accent = accentColor(scenario.accent);
    final disabled = widget.disabled;
    final starting = widget.starting;
    final onStart = widget.onStart;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.zero,
        hoverColor: AppColors.layerHover,
        splashColor: Colors.transparent,
        highlightColor: AppColors.layerActive,
        onFocusChange: (value) => setState(() => _focused = value),
        onTap: disabled || starting ? null : onStart,
        child: Container(
          constraints: const BoxConstraints(minHeight: 232),
          padding: const EdgeInsets.all(16),
          foregroundDecoration: _focused
              ? BoxDecoration(
                  border: Border.all(color: AppColors.focus, width: 2),
                )
              : null,
          decoration: BoxDecoration(
            color: AppColors.layer,
            borderRadius: BorderRadius.zero,
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Pill(label: scenario.channel.toUpperCase(), color: accent),
                  const Spacer(),
                  _Difficulty(value: scenario.difficulty, color: accent),
                ],
              ),
              const SizedBox(height: 16),
              if (scenario.org.isNotEmpty) ...[
                Text(
                  scenario.org,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: kMono.copyWith(
                    color: AppColors.textHelper,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
              ],
              Semantics(
                header: true,
                child: Text(
                  scenario.title,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                scenario.teaser,
                style: const TextStyle(
                  fontFamily: 'IBMPlexSans',
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  height: 1.43,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${scenario.flagCount} red flag${scenario.flagCount == 1 ? '' : 's'} · '
                      '${scenario.maxTurns} turn${scenario.maxTurns == 1 ? '' : 's'}',
                      style: kMono.copyWith(
                        color: AppColors.textHelper,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  FilledButton(
                    onPressed: disabled || starting ? null : onStart,
                    child: starting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(disabled ? 'AI offline' : 'Start round'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Difficulty extends StatelessWidget {
  final int value;
  final Color color;

  const _Difficulty({required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final level = value.clamp(1, 3);
    return Semantics(
      label: 'Difficulty $level of 3',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 1; i <= 3; i++)
              Container(
                width: 14,
                height: 4,
                margin: EdgeInsets.only(left: i == 1 ? 0 : 3),
                color: i <= level ? color : AppColors.borderSubtle,
              ),
          ],
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
      final value =
          match.group(0)?.replaceFirst(RegExp(r'[.,;:!?)\]}]+$'), '') ?? '';
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
        child: Pill(label: entry.text, color: AppColors.textHelper),
      );
    }

    final isUser = entry.role == 'user';
    final urls = isUser ? const <String>[] : _urls(entry.text);
    final accent = isUser ? AppColors.interactive : AppColors.supportWarning;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: math.min(MediaQuery.sizeOf(context).width * 0.82, 620.0),
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.layer,
            borderRadius: BorderRadius.zero,
            border: Border(
              left: BorderSide(color: accent, width: 3),
              top: const BorderSide(color: AppColors.borderSubtle),
              right: const BorderSide(color: AppColors.borderSubtle),
              bottom: const BorderSide(color: AppColors.borderSubtle),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isUser ? 'You' : 'Scammer',
                style: TextStyle(
                  fontFamily: 'IBMPlexSans',
                  color: accent,
                  fontSize: 12,
                  height: 1.34,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.32,
                ),
              ),
              const SizedBox(height: 8),
              SelectableText(
                entry.text,
                style: const TextStyle(
                  fontFamily: 'IBMPlexSans',
                  fontSize: 14,
                  height: 1.43,
                  color: AppColors.textPrimary,
                ),
              ),
              if (urls.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    for (final url in urls)
                      TextButton.icon(
                        onPressed: () => onLink(url),
                        icon: const Icon(Icons.open_in_new, size: 16),
                        label: Text(_host(url)),
                        style: ghostButtonStyle.copyWith(
                          minimumSize: const WidgetStatePropertyAll(
                            Size(0, 32),
                          ),
                          padding: const WidgetStatePropertyAll(
                            EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                          ),
                          textStyle: WidgetStatePropertyAll(
                            kMono.copyWith(fontSize: 12, color: AppColors.link),
                          ),
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
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.borderSubtle)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            flag.spotted ? Icons.check_circle : Icons.cancel,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 12),
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
                        style: const TextStyle(
                          fontFamily: 'IBMPlexSans',
                          fontSize: 14,
                          height: 1.43,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Pill(
                      label: flag.severity,
                      color: severityColor(flag.severity),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  flag.explanation,
                  style: const TextStyle(
                    fontFamily: 'IBMPlexSans',
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    height: 1.34,
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

  const _BreakdownRow({
    required this.label,
    required this.value,
    this.total = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.borderSubtle)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'IBMPlexSans',
                color: total ? AppColors.textPrimary : AppColors.textSecondary,
                fontSize: 14,
                height: 1.43,
                fontWeight: total ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
          Text(
            value,
            style: kMono.copyWith(
              color: total ? AppColors.textPrimary : AppColors.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

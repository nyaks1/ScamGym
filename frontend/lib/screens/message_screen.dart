import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../api.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/app_footer.dart';
import '../widgets/common.dart';

class MessageScreen extends StatefulWidget {
  final ApiClient api;

  const MessageScreen({super.key, required this.api});

  @override
  State<MessageScreen> createState() => _MessageScreenState();
}

class _Sample {
  final String label;
  final String value;

  const _Sample(this.label, this.value);
}

class _MessageScreenState extends State<MessageScreen> {
  final TextEditingController _controller = TextEditingController();
  bool _loading = false;
  MessageReport? _report;
  String? _error;

  static const _samples = [
    _Sample(
      'Bank OTP request',
      'KALAHARI BANK: Suspicious login on account ending 4417. Reply with the OTP we just sent to '
          'cancel the transfer. Do not tell anyone.',
    ),
    _Sample(
      'Grant fee',
      'UBUNTU GRANTS: Your R2,200 grant is approved. Pay the R99 admin fee today at '
          'https://ubuntu-grants-pay.example.com/claim or lose the payout. WhatsApp 072 000 0199.',
    ),
    _Sample(
      'Parcel fee',
      'ParcelPal: Parcel PP-4471 held at depot. Pay R37 customs here: '
          'https://parcelpal-fees.example.com/pay within 24 hours or it returns to sender.',
    ),
    _Sample('Benign message', 'Hi Mom, I will be home around 6. Please buy bread on the way. Love you.'),
  ];

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onText);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onText)
      ..dispose();
    super.dispose();
  }

  void _onText() {
    if (mounted) setState(() {});
  }

  Future<void> _check([String? value]) async {
    final text = (value ?? _controller.text).trim();
    if (text.isEmpty) {
      _snack('Paste a message first.');
      return;
    }
    _controller.text = text;
    setState(() {
      _loading = true;
      _error = null;
      _report = null;
    });
    try {
      final report = await widget.api.checkMessage(text);
      if (!mounted) return;
      setState(() {
        _report = report;
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

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = math.min(constraints.maxWidth, 960.0);
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _head(),
                  const SizedBox(height: 12),
                  const Text(
                    'Paste an SMS, WhatsApp or email. Plain Python matches the language patterns scams '
                    'rely on and runs every link through the link checker. Do not paste real personal '
                    'details; the text goes to Gemini only for the optional plain-language explanation.',
                    style: TextStyle(color: AppColors.muted, fontSize: 13.5, height: 1.55),
                  ),
                  const SizedBox(height: 18),
                  _form(),
                  const SizedBox(height: 12),
                  _sampleRow(),
                  const SizedBox(height: 16),
                  if (_loading) const LoadingLine('Reading the message…'),
                  if (_error != null) ...[
                    SectionCard(
                      border: Border.all(color: AppColors.red.withValues(alpha: 0.4)),
                      color: AppColors.red.withValues(alpha: 0.05),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Color(0xFFFFC0C0), fontSize: 13, height: 1.5),
                      ),
                    ),
                  ],
                  if (_report != null) _MessageResult(report: _report!),
                  const AppFooter(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _head() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final title = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Eyebrow('Message checker'),
            const SizedBox(height: 6),
            Text(
              'Check a message before you reply',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        );
        const pill = Pill(label: 'Code scores the signals', color: AppColors.lime);
        if (constraints.maxWidth >= 620) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [Expanded(child: title), const SizedBox(width: 14), pill],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [title, const SizedBox(height: 10), pill],
        );
      },
    );
  }

  Widget _form() {
    final count = _controller.text.length;
    return SectionCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Eyebrow('Message text', color: AppColors.muted),
          const SizedBox(height: 8),
          TextField(
            controller: _controller,
            minLines: 5,
            maxLines: 9,
            maxLength: 5000,
            keyboardType: TextInputType.multiline,
            style: const TextStyle(fontSize: 13.5, height: 1.5),
            decoration: scamInput(hint: 'Paste the message here…').copyWith(
              counterText: '',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                '$count / 5000',
                style: kMono.copyWith(color: AppColors.muted2, fontSize: 10),
              ),
              const Spacer(),
              FilledButton(
                onPressed: _loading ? null : _check,
                style: primaryButtonStyle,
                child: _loading
                    ? const SizedBox(
                        width: 15,
                        height: 15,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Check message'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sampleRow() {
    return Wrap(
      spacing: 7,
      runSpacing: 7,
      children: [
        for (final sample in _samples)
          OutlinedButton(
            onPressed: _loading ? null : () => _check(sample.value),
            style: secondaryButtonStyle.copyWith(
              padding: const WidgetStatePropertyAll(
                EdgeInsets.symmetric(horizontal: 11, vertical: 7),
              ),
            ),
            child: Text(
              sample.label,
              style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
            ),
          ),
      ],
    );
  }
}

class _MessageResult extends StatelessWidget {
  final MessageReport report;

  const _MessageResult({required this.report});

  @override
  Widget build(BuildContext context) {
    final color = verdictColor(report.verdict);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final info = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  VerdictChip(verdict: report.verdict, label: report.verdictLabel),
                  const SizedBox(height: 10),
                  Text(
                    report.verdictLabel,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: color),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${report.findings.length} signal${report.findings.length == 1 ? '' : 's'} matched · '
                    '${report.links.length} link${report.links.length == 1 ? '' : 's'} checked',
                    style: kMono.copyWith(color: AppColors.muted, fontSize: 10.5),
                  ),
                ],
              );
              final ring = ScoreRing(score: report.score, size: 88, color: color);
              if (constraints.maxWidth >= 560) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(child: info),
                    const SizedBox(width: 16),
                    ring,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: info),
                  const SizedBox(width: 12),
                  ring,
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          const Divider(),
          const SizedBox(height: 14),
          const Eyebrow('Signals', color: AppColors.muted),
          const SizedBox(height: 10),
          if (report.findings.isEmpty)
            const EmptyNote(
              'No common scam signals found. That is not a guarantee: verify unexpected requests independently.',
            )
          else
            for (final finding in report.findings) FindingTile(finding: finding),
          if (report.links.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Eyebrow('Links in the message', color: AppColors.muted),
            const SizedBox(height: 10),
            for (final link in report.links) LinkSummaryTile(link: link),
          ],
          if (report.phoneNumbers.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Eyebrow('Numbers in the message', color: AppColors.muted),
            const SizedBox(height: 8),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                for (final number in report.phoneNumbers)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.text.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.lineSoft),
                    ),
                    child: Text(
                      number,
                      style: kMono.copyWith(color: AppColors.muted, fontSize: 11),
                    ),
                  ),
              ],
            ),
          ],
          if (report.aiExplanation != null) ...[
            const SizedBox(height: 14),
            CoachRead(text: report.aiExplanation!),
          ],
          const SizedBox(height: 18),
          const Eyebrow('What to do', color: AppColors.muted),
          const SizedBox(height: 10),
          AdviceList(items: report.advice),
          if (report.notChecked.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Eyebrow('What this check cannot see', color: AppColors.muted2),
            const SizedBox(height: 8),
            for (final item in report.notChecked)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('· ', style: kMono.copyWith(color: AppColors.muted2)),
                    Expanded(
                      child: Text(
                        item,
                        style: const TextStyle(
                          color: AppColors.muted2,
                          fontSize: 11.5,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

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
  final GlobalKey _resultKey = GlobalKey();
  final GlobalKey _formKey = GlobalKey();
  bool _loading = false;
  MessageReport? _report;
  String? _error;

  static const _maxLength = 5000;

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
    _Sample(
      'Benign message',
      'Hi Mom, I will be home around 6. Please buy bread on the way. Love you.',
    ),
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

  void _clear() {
    _controller.clear();
    setState(() {
      _report = null;
      _error = null;
    });
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
      _scrollToResult();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  void _scrollToResult() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final resultContext = _resultKey.currentContext;
      if (resultContext == null) return;
      Scrollable.ensureVisible(
        resultContext,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOut,
        alignment: 0.02,
      );
    });
  }

  void _scrollToForm() {
    final formContext = _formKey.currentContext;
    if (formContext == null) return;
    Scrollable.ensureVisible(
      formContext,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOut,
      alignment: 0.05,
    );
  }

  void _snack(String message) {
    showScamSnackBar(context, message);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = math.min(constraints.maxWidth, 960.0);
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _head(),
                  const SizedBox(height: 8),
                  const Text(
                    'Paste an SMS, WhatsApp or email. Plain Python matches the language patterns scams '
                    'rely on and runs every link through the link checker. Do not paste real personal '
                    'details; the text goes to Gemini only for the optional plain-language explanation.',
                    style: TextStyle(
                      fontFamily: 'IBMPlexSans',
                      color: AppColors.textSecondary,
                      fontSize: 14,
                      height: 1.43,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _form(),
                  const SizedBox(height: 16),
                  const Eyebrow('Examples'),
                  const SizedBox(height: 8),
                  _sampleRow(),
                  const SizedBox(height: 24),
                  if (_loading) const LoadingLine('Reading the message…'),
                  if (_error != null) ...[
                    InlineNotice(
                      kind: 'error',
                      title: 'Could not check the message',
                      message: _error!,
                    ),
                  ],
                  if (_report != null)
                    _MessageResult(
                      key: _resultKey,
                      report: _report!,
                      onCheckAnother: _scrollToForm,
                    ),
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
            const SizedBox(height: 8),
            Text(
              'Check a message before you reply',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        );
        const pill = Pill(
          label: 'Code scores the signals',
          color: AppColors.supportSuccess,
        );
        if (constraints.maxWidth >= 620) {
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

  Widget _form() {
    final count = _controller.text.length;
    return SectionCard(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Eyebrow('Message text'),
          const SizedBox(height: 8),
          Semantics(
            label: 'Message text',
            child: TextField(
              controller: _controller,
              minLines: 5,
              maxLines: 9,
              maxLength: _maxLength,
              keyboardType: TextInputType.multiline,
              style: const TextStyle(
                fontFamily: 'IBMPlexSans',
                fontSize: 14,
                height: 1.43,
                color: AppColors.textPrimary,
              ),
              decoration: scamInput(
                hint: 'Paste the message here…',
                suffix: _controller.text.isEmpty
                    ? null
                    : ClearFieldButton(
                        onPressed: _clear,
                        tooltip: 'Clear the message',
                      ),
              ).copyWith(counterText: '', alignLabelWithHint: true),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '$count / $_maxLength',
                style: kMono.copyWith(
                  color: AppColors.textHelper,
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              FilledButton(
                onPressed: _loading ? null : _check,
                child: _loading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
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
      spacing: 4,
      runSpacing: 4,
      children: [
        for (final sample in _samples)
          TextButton(
            onPressed: _loading ? null : () => _check(sample.value),
            style: ghostButtonStyle.copyWith(
              minimumSize: const WidgetStatePropertyAll(Size(0, 32)),
              padding: const WidgetStatePropertyAll(
                EdgeInsets.symmetric(horizontal: 8, vertical: 0),
              ),
            ),
            child: Text(sample.label),
          ),
      ],
    );
  }
}

class _MessageResult extends StatelessWidget {
  final MessageReport report;
  final VoidCallback onCheckAnother;

  const _MessageResult({
    super.key,
    required this.report,
    required this.onCheckAnother,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.layer,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ReportHead(
            verdict: report.verdict,
            verdictLabel: report.verdictLabel,
            score: report.score,
            details: Text(
              '${report.findings.length} signal${report.findings.length == 1 ? '' : 's'} matched · '
              '${report.links.length} link${report.links.length == 1 ? '' : 's'} checked',
              style: kMono.copyWith(
                color: AppColors.textHelper,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 24),
          const SectionLabel('Signals'),
          const SizedBox(height: 12),
          if (report.findings.isEmpty)
            const EmptyNote(
              'No common scam signals found. That is not a guarantee: verify unexpected requests independently.',
            )
          else
            for (final finding in report.findings)
              FindingTile(finding: finding),
          if (report.links.isNotEmpty) ...[
            const SizedBox(height: 24),
            const SectionLabel('Links in the message'),
            const SizedBox(height: 12),
            for (final link in report.links) LinkSummaryTile(link: link),
          ],
          if (report.phoneNumbers.isNotEmpty) ...[
            const SizedBox(height: 24),
            const SectionLabel('Numbers in the message'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final number in report.phoneNumbers)
                  Pill(
                    label: number,
                    color: AppColors.textHelper,
                    icon: Icons.phone_outlined,
                  ),
              ],
            ),
          ],
          if (report.aiExplanation != null) ...[
            const SizedBox(height: 16),
            CoachRead(text: report.aiExplanation!),
          ],
          const SizedBox(height: 24),
          const SectionLabel('What to do'),
          const SizedBox(height: 12),
          AdviceList(items: report.advice),
          if (report.notChecked.isNotEmpty) ...[
            const SizedBox(height: 24),
            NotCheckedList(items: report.notChecked),
          ],
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: onCheckAnother,
            icon: const Icon(Icons.arrow_upward, size: 16),
            label: const Text('Check another message'),
          ),
        ],
      ),
    );
  }
}

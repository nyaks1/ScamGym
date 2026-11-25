import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../api.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/app_footer.dart';
import '../widgets/common.dart';

class LinkScreen extends StatefulWidget {
  final ApiClient api;

  const LinkScreen({super.key, required this.api});

  @override
  State<LinkScreen> createState() => _LinkScreenState();
}

class _Sample {
  final String label;
  final String value;

  const _Sample(this.label, this.value);
}

class _LinkScreenState extends State<LinkScreen> {
  final TextEditingController _controller = TextEditingController();
  final GlobalKey _resultKey = GlobalKey();
  final GlobalKey _formKey = GlobalKey();
  bool _loading = false;
  LinkReport? _report;
  String? _error;

  static const _maxLength = 2048;

  static const _samples = [
    _Sample(
      'Lookalike bank link',
      'http://kalahari-bank.example.com.verify-login.top/reverse',
    ),
    _Sample('Shortened link', 'https://bit.ly/3xample'),
    _Sample('Raw IP address', 'http://197.0.0.1/login'),
    _Sample(
      'Practice domain',
      'https://kalahari-bank-secure.example.com/reverse',
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
    final url = (value ?? _controller.text).trim();
    if (url.isEmpty) {
      _snack('Paste a web address first.');
      return;
    }
    _controller.text = url;
    setState(() {
      _loading = true;
      _error = null;
      _report = null;
    });
    try {
      final report = await widget.api.checkLink(url);
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
                    'Paste a suspicious web address. ScamGym reads it as text and scores the structural '
                    'warning signs: lookalike domains, raw IPs, shorteners, suspicious endings and '
                    'credential-harvest paths. The verdict is computed by code, not guessed by a model.',
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
                  if (_loading) const LoadingLine('Reading the address…'),
                  if (_error != null) ...[
                    InlineNotice(
                      kind: 'error',
                      title: 'Could not check the link',
                      message: _error!,
                    ),
                  ],
                  if (_report != null)
                    _LinkResult(
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
            const Eyebrow('Link checker'),
            const SizedBox(height: 8),
            Text(
              'Check a link before you click',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        );
        const pill = Pill(
          label: 'Never opens the link',
          color: AppColors.supportInfo,
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
    return SectionCard(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Eyebrow('Web address'),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final field = Semantics(
                label: 'Web address',
                child: TextField(
                  controller: _controller,
                  autocorrect: false,
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.go,
                  maxLength: _maxLength,
                  onSubmitted: (_) => _check(),
                  style: const TextStyle(
                    fontFamily: 'IBMPlexMono',
                    fontSize: 14,
                    height: 1.43,
                    color: AppColors.textPrimary,
                  ),
                  decoration: scamInput(
                    hint: 'https://…',
                    suffix: _controller.text.isEmpty
                        ? null
                        : ClearFieldButton(
                            onPressed: _clear,
                            tooltip: 'Clear the web address',
                          ),
                  ).copyWith(counterText: ''),
                ),
              );
              final button = FilledButton(
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
                    : const Text('Check link'),
              );
              if (constraints.maxWidth >= 560) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(child: field),
                    const SizedBox(width: 16),
                    button,
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [field, const SizedBox(height: 16), button],
              );
            },
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

class _LinkResult extends StatelessWidget {
  final LinkReport report;
  final VoidCallback onCheckAnother;

  const _LinkResult({
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
            details: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(
                  report.host.isEmpty ? report.input : report.host,
                  style: kMono.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
                if (report.normalized.isNotEmpty &&
                    report.normalized != report.input) ...[
                  const SizedBox(height: 4),
                  SelectableText(
                    report.normalized,
                    style: kMono.copyWith(
                      color: AppColors.textHelper,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (report.isDemo) ...[
            const SizedBox(height: 24),
            const InlineNotice(
              kind: 'info',
              title: 'Practice domain',
              message:
                  'This is a reserved practice domain from the simulation. example.com and example.test '
                  'cannot reach a real organisation.',
            ),
          ],
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 24),
          const SectionLabel('Signals'),
          const SizedBox(height: 12),
          if (report.findings.isEmpty)
            const EmptyNote(
              'No structural red flags found. That is not a guarantee that the site is safe.',
            )
          else
            for (final finding in report.findings)
              FindingTile(finding: finding),
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
            label: const Text('Check another link'),
          ),
        ],
      ),
    );
  }
}

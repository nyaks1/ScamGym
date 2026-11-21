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
  bool _loading = false;
  LinkReport? _report;
  String? _error;

  static const _samples = [
    _Sample('Lookalike bank link', 'http://kalahari-bank.example.com.verify-login.top/reverse'),
    _Sample('Shortened link', 'https://bit.ly/3xample'),
    _Sample('Raw IP address', 'http://197.0.0.1/login'),
    _Sample('Practice domain', 'https://kalahari-bank-secure.example.com/reverse'),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
                    'Paste a suspicious web address. ScamGym reads it as text and scores the structural '
                    'warning signs: lookalike domains, raw IPs, shorteners, suspicious endings and '
                    'credential-harvest paths. The verdict is computed by code, not guessed by a model.',
                    style: TextStyle(color: AppColors.muted, fontSize: 13.5, height: 1.55),
                  ),
                  const SizedBox(height: 18),
                  _form(),
                  const SizedBox(height: 12),
                  _sampleRow(),
                  const SizedBox(height: 16),
                  if (_loading) const LoadingLine('Reading the address…'),
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
                  if (_report != null) _LinkResult(report: _report!),
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
            const SizedBox(height: 6),
            Text(
              'Check a link before you click',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        );
        const pill = Pill(label: 'Never opens the link', color: AppColors.sky);
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
    return SectionCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Eyebrow('Web address', color: AppColors.muted),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final field = TextField(
                controller: _controller,
                autocorrect: false,
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.go,
                onSubmitted: (_) => _check(),
                style: kMono.copyWith(fontSize: 13),
                decoration: scamInput(hint: 'https://…'),
              );
              final button = FilledButton(
                onPressed: _loading ? null : _check,
                style: primaryButtonStyle,
                child: _loading
                    ? const SizedBox(
                        width: 15,
                        height: 15,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Check link'),
              );
              if (constraints.maxWidth >= 560) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: field),
                    const SizedBox(width: 10),
                    button,
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [field, const SizedBox(height: 10), button],
              );
            },
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

class _LinkResult extends StatelessWidget {
  final LinkReport report;

  const _LinkResult({required this.report});

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
                  SelectableText(
                    report.host.isEmpty ? report.input : report.host,
                    style: kMono.copyWith(color: AppColors.muted, fontSize: 12),
                  ),
                  if (report.normalized.isNotEmpty && report.normalized != report.input) ...[
                    const SizedBox(height: 3),
                    SelectableText(
                      report.normalized,
                      style: kMono.copyWith(color: AppColors.muted2, fontSize: 10.5),
                    ),
                  ],
                ],
              );
              final ring = ScoreRing(
                score: report.score,
                size: 88,
                color: color,
              );
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
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: info),
                      const SizedBox(width: 12),
                      ring,
                    ],
                  ),
                ],
              );
            },
          ),
          if (report.isDemo) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.sky.withValues(alpha: 0.06),
                border: Border.all(color: AppColors.sky.withValues(alpha: 0.3)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'This is a reserved practice domain from the simulation. example.com and example.test '
                'cannot reach a real organisation.',
                style: TextStyle(color: Color(0xFFCFEAF6), fontSize: 12.5, height: 1.5),
              ),
            ),
          ],
          const SizedBox(height: 18),
          const Divider(),
          const SizedBox(height: 14),
          const Eyebrow('Signals', color: AppColors.muted),
          const SizedBox(height: 10),
          if (report.findings.isEmpty)
            const EmptyNote('No structural red flags found. That is not a guarantee that the site is safe.')
          else
            for (final finding in report.findings) FindingTile(finding: finding),
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

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';

/// Carbon-style snackbar with an icon so status is not carried by colour alone.
void showScamSnackBar(
  BuildContext context,
  String message, {
  bool error = false,
}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              error ? Icons.error : Icons.info,
              size: 20,
              color: error ? AppColors.supportError : AppColors.supportInfo,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
}

/// Carbon-style inline notification used for errors, status, and guidance.
class InlineNotice extends StatelessWidget {
  /// One of: error, warning, info, success.
  final String kind;
  final String? title;
  final String message;
  final Widget? action;

  const InlineNotice({
    super.key,
    required this.kind,
    this.title,
    required this.message,
    this.action,
  });

  Color get _color {
    switch (kind) {
      case 'error':
        return AppColors.supportError;
      case 'warning':
        return AppColors.supportWarning;
      case 'success':
        return AppColors.supportSuccess;
      default:
        return AppColors.supportInfo;
    }
  }

  IconData get _icon {
    switch (kind) {
      case 'error':
        return Icons.error;
      case 'warning':
        return Icons.warning;
      case 'success':
        return Icons.check_circle;
      default:
        return Icons.info;
    }
  }

  String get _kindLabel {
    switch (kind) {
      case 'error':
        return 'Error';
      case 'warning':
        return 'Warning';
      case 'success':
        return 'Success';
      default:
        return 'Information';
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.layer,
        border: Border(
          left: BorderSide(color: _color, width: 3),
          top: const BorderSide(color: AppColors.borderSubtle),
          right: const BorderSide(color: AppColors.borderSubtle),
          bottom: const BorderSide(color: AppColors.borderSubtle),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_icon, size: 20, color: _color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title ?? _kindLabel,
                  style: const TextStyle(
                    fontFamily: 'IBMPlexSans',
                    fontSize: 14,
                    height: 1.43,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: const TextStyle(
                    fontFamily: 'IBMPlexSans',
                    fontSize: 14,
                    height: 1.43,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (action != null) ...[const SizedBox(height: 12), action!],
              ],
            ),
          ),
        ],
      ),
    );
    return Semantics(container: true, liveRegion: true, child: content);
  }
}

class SimBanner extends StatelessWidget {
  const SimBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.layer,
        border: Border(
          left: BorderSide(color: AppColors.supportWarning, width: 3),
          bottom: BorderSide(color: AppColors.borderSubtle),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(
        alignment: WrapAlignment.start,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 2,
        children: [
          const Icon(Icons.warning, size: 16, color: AppColors.supportWarning),
          const Text(
            'Simulation only',
            style: TextStyle(
              fontFamily: 'IBMPlexSans',
              fontSize: 14,
              height: 1.29,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          Text(
            'Fictional brands, people, numbers and links.',
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class Eyebrow extends StatelessWidget {
  final String text;
  final Color? color;

  const Eyebrow(this.text, {super.key, this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontFamily: 'IBMPlexSans',
        fontSize: 12,
        height: 1.34,
        letterSpacing: 0.32,
        fontWeight: FontWeight.w500,
        color: color ?? AppColors.textHelper,
      ),
    );
  }
}

class SectionLabel extends StatelessWidget {
  final String text;

  const SectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontFamily: 'IBMPlexSans',
        fontSize: 14,
        height: 1.43,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    );
  }
}

/// Carbon tag. Read-only tags use a 24px pill with 12px text.
class Pill extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const Pill({
    super.key,
    required this.label,
    this.color = AppColors.interactive,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final content = Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        border: Border.all(color: color.withValues(alpha: 0.55)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
          ] else ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'IBMPlexSans',
                fontSize: 12,
                height: 1.34,
                fontWeight: FontWeight.w400,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
    return Semantics(
      container: true,
      label: label,
      child: ExcludeSemantics(child: content),
    );
  }
}

class VerdictChip extends StatelessWidget {
  final String verdict;
  final String label;

  const VerdictChip({super.key, required this.verdict, required this.label});

  @override
  Widget build(BuildContext context) {
    return Pill(label: label, color: verdictColor(verdict));
  }
}

class SectionCard extends StatelessWidget {
  final String? title;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Border? border;

  const SectionCard({
    super.key,
    this.title,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? AppColors.layer,
        borderRadius: BorderRadius.zero,
        border: border ?? Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Semantics(
              header: true,
              child: Text(
                title!,
                style: const TextStyle(
                  fontFamily: 'IBMPlexSans',
                  fontSize: 14,
                  height: 1.43,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          child,
        ],
      ),
    );
  }
}

class ScoreRing extends StatelessWidget {
  final int score;
  final double size;
  final Color? color;

  const ScoreRing({
    super.key,
    required this.score,
    this.size = 132,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final ringColor = color ?? scoreColor(score);
    return Semantics(
      container: true,
      label: 'Score',
      value: '${score.clamp(0, 100)} out of 100',
      excludeSemantics: true,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: score.clamp(0, 100).toDouble() / 100),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
        builder: (context, value, _) {
          return SizedBox(
            width: size,
            height: size,
            child: CustomPaint(
              painter: _RingPainter(progress: value, color: ringColor),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '$score',
                      style: TextStyle(
                        fontFamily: 'IBMPlexSans',
                        color: AppColors.textPrimary,
                        fontSize: size * 0.3,
                        fontWeight: FontWeight.w300,
                        height: 1,
                        letterSpacing: 0,
                      ),
                    ),
                    Text(
                      '/100',
                      style: TextStyle(
                        fontFamily: 'IBMPlexMono',
                        color: AppColors.textHelper,
                        fontSize: size * 0.085,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;

  const _RingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = (size.width * 0.045).clamp(3.0, 6.0);
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = (size.width - stroke) / 2;

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = AppColors.borderSubtle
      ..strokeCap = StrokeCap.butt;

    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = color
      ..strokeCap = StrokeCap.butt;

    canvas.drawCircle(center, radius, track);
    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * progress.clamp(0.0, 1.0),
        false,
        arc,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

class FindingTile extends StatelessWidget {
  final Finding finding;

  const FindingTile({super.key, required this.finding});

  @override
  Widget build(BuildContext context) {
    final color = severityColor(finding.severity);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 12, 16, 12),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: color, width: 3),
          bottom: const BorderSide(color: AppColors.borderSubtle),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  finding.label,
                  style: const TextStyle(
                    fontFamily: 'IBMPlexSans',
                    fontSize: 14,
                    height: 1.43,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (finding.weight > 0) ...[
                const SizedBox(width: 10),
                Text(
                  '+${finding.weight}',
                  style: kMono.copyWith(
                    color: AppColors.textHelper,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
          if (finding.detail.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              finding.detail,
              style: const TextStyle(
                fontFamily: 'IBMPlexSans',
                fontSize: 14,
                height: 1.43,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class AdviceList extends StatelessWidget {
  final List<String> items;
  final bool compact;

  const AdviceList({super.key, required this.items, this.compact = false});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Text(
        'Nothing specific to add.',
        style: TextStyle(
          fontFamily: 'IBMPlexSans',
          color: AppColors.textSecondary,
          fontSize: 14,
          height: 1.43,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 4,
                  height: 4,
                  margin: const EdgeInsets.only(top: 7, right: 10),
                  decoration: const BoxDecoration(
                    color: AppColors.textHelper,
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: Text(
                    item,
                    style: TextStyle(
                      fontFamily: 'IBMPlexSans',
                      fontSize: compact ? 12 : 14,
                      height: 1.43,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class LinkSummaryTile extends StatelessWidget {
  final LinkReport link;

  const LinkSummaryTile({super.key, required this.link});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.borderSubtle),
        borderRadius: BorderRadius.zero,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(
                  link.host.isEmpty ? link.input : link.host,
                  style: kMono.copyWith(
                    fontSize: 12,
                    height: 1.34,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    VerdictChip(
                      verdict: link.verdict,
                      label: link.verdictLabel,
                    ),
                    Text(
                      'Not opened',
                      style: kMono.copyWith(
                        color: AppColors.textHelper,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '${link.score}',
            style: TextStyle(
              fontFamily: 'IBMPlexMono',
              color: verdictColor(link.verdict),
              fontSize: 20,
              height: 1.2,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

class EmptyNote extends StatelessWidget {
  final String text;

  const EmptyNote(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.borderSubtle),
        borderRadius: BorderRadius.zero,
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'IBMPlexSans',
          color: AppColors.textSecondary,
          fontSize: 14,
          height: 1.43,
        ),
      ),
    );
  }
}

class CoachRead extends StatelessWidget {
  final String text;

  const CoachRead({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return InlineNotice(kind: 'info', title: "Coach's read", message: text);
  }
}

class LoadingLine extends StatelessWidget {
  final String label;

  const LoadingLine(this.label, {super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      liveRegion: true,
      label: label,
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.interactive,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              label,
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
    );
  }
}

/// Small icon-only control that clears a text field.
///
/// Carbon text inputs can offer a clear affordance; the 32px hit area keeps it
/// comfortable without breaking the dense 40px field.
class ClearFieldButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String tooltip;

  const ClearFieldButton({
    super.key,
    required this.onPressed,
    this.tooltip = 'Clear',
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: const Icon(Icons.close, size: 16, color: AppColors.textHelper),
      style: ButtonStyle(
        overlayColor: WidgetStateProperty.resolveWith(iconButtonOverlay),
        minimumSize: const WidgetStatePropertyAll(Size(32, 32)),
        padding: const WidgetStatePropertyAll(EdgeInsets.zero),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: const WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        ),
      ),
    );
  }
}

/// The limits of a deterministic check, shown as a quiet bullet list.
class NotCheckedList extends StatelessWidget {
  final List<String> items;

  const NotCheckedList({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Eyebrow('What this check cannot see'),
        const SizedBox(height: 8),
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('·', style: kMono.copyWith(color: AppColors.textHelper)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item,
                    style: const TextStyle(
                      fontFamily: 'IBMPlexSans',
                      color: AppColors.textHelper,
                      fontSize: 12,
                      height: 1.34,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Shared verdict header for the link and message checkers.
///
/// Keeps the score, verdict and the report's identifying detail in the same
/// place on both screens. The verdict title is a polite live region so a
/// screen reader hears the result as soon as the check returns.
class ReportHead extends StatelessWidget {
  final String verdict;
  final String verdictLabel;
  final int score;
  final Widget? details;
  final double ringSize;

  const ReportHead({
    super.key,
    required this.verdict,
    required this.verdictLabel,
    required this.score,
    this.details,
    this.ringSize = 104,
  });

  @override
  Widget build(BuildContext context) {
    final color = verdictColor(verdict);
    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        VerdictChip(verdict: verdict, label: verdictLabel),
        const SizedBox(height: 16),
        Semantics(
          container: true,
          liveRegion: true,
          child: Text(
            verdictLabel,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: color,
            ),
          ),
        ),
        if (details != null) ...[const SizedBox(height: 8), details!],
      ],
    );
    final ring = ScoreRing(score: score, size: ringSize, color: color);

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 560) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: info),
              const SizedBox(width: 24),
              ring,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: info),
            const SizedBox(width: 16),
            ring,
          ],
        );
      },
    );
  }
}

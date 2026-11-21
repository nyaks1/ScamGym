import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';

class SimBanner extends StatelessWidget {
  const SimBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      decoration: const BoxDecoration(
        color: Color(0xFF1B1508),
        border: Border(bottom: BorderSide(color: Color(0xFF3A2C10))),
      ),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 10,
        runSpacing: 2,
        children: [
          Text(
            'SIMULATION ONLY',
            style: kMonoSmall.copyWith(color: AppColors.amber, letterSpacing: 1.6),
          ),
          Text(
            'Fictional brands, people, numbers and links.',
            style: kMono.copyWith(color: const Color(0xFFC9AB74), fontSize: 10.5),
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
      text.toUpperCase(),
      style: kMonoSmall.copyWith(color: color ?? AppColors.lime, letterSpacing: 1.5),
    );
  }
}

class Pill extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const Pill({
    super.key,
    required this.label,
    this.color = AppColors.lime,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        border: Border.all(color: color.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 5),
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
              style: kMono.copyWith(
                color: color,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class VerdictChip extends StatelessWidget {
  final String verdict;
  final String label;

  const VerdictChip({super.key, required this.verdict, required this.label});

  @override
  Widget build(BuildContext context) {
    final color = verdictColor(verdict);
    return Pill(label: label.toUpperCase(), color: color);
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
        color: color ?? AppColors.panel2,
        borderRadius: BorderRadius.circular(16),
        border: border ?? Border.all(color: AppColors.lineSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Eyebrow(title!, color: AppColors.muted),
            const SizedBox(height: 12),
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

  const ScoreRing({super.key, required this.score, this.size = 132, this.color});

  @override
  Widget build(BuildContext context) {
    final ringColor = color ?? scoreColor(score);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: score.clamp(0, 100).toDouble() / 100),
      duration: const Duration(milliseconds: 750),
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
                    style: kMono.copyWith(
                      color: AppColors.text,
                      fontSize: size * 0.29,
                      fontWeight: FontWeight.w700,
                      height: 1,
                      letterSpacing: -2,
                    ),
                  ),
                  Text(
                    '/100',
                    style: kMono.copyWith(
                      color: AppColors.muted2,
                      fontSize: size * 0.085,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;

  const _RingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.075;
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = (size.width - stroke) / 2;

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = AppColors.line
      ..strokeCap = StrokeCap.round;

    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = color
      ..strokeCap = StrokeCap.round;

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
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.text.withValues(alpha: 0.018),
        border: Border(left: BorderSide(color: color, width: 3)),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(9),
          bottomRight: Radius.circular(9),
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
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),
              ),
              if (finding.weight > 0) ...[
                const SizedBox(width: 10),
                Text(
                  '+${finding.weight}',
                  style: kMono.copyWith(color: AppColors.muted2, fontSize: 10.5),
                ),
              ],
            ],
          ),
          if (finding.detail.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              finding.detail,
              style: const TextStyle(fontSize: 12.5, height: 1.45, color: AppColors.muted),
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
        style: TextStyle(color: AppColors.muted, fontSize: 13),
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
                  width: 5,
                  height: 5,
                  margin: const EdgeInsets.only(top: 7, right: 9),
                  decoration: const BoxDecoration(
                    color: AppColors.lime,
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: Text(
                    item,
                    style: TextStyle(
                      fontSize: compact ? 12.5 : 13,
                      height: 1.5,
                      color: AppColors.muted,
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.text.withValues(alpha: 0.018),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.lineSoft),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  link.host.isEmpty ? link.input : link.host,
                  style: kMono.copyWith(fontSize: 12.5, height: 1.4),
                ),
                const SizedBox(height: 5),
                Wrap(
                  spacing: 8,
                  runSpacing: 5,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    VerdictChip(verdict: link.verdict, label: link.verdictLabel),
                    Text(
                      'Not opened',
                      style: kMono.copyWith(color: AppColors.muted2, fontSize: 10),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '${link.score}',
            style: kMono.copyWith(
              color: verdictColor(link.verdict),
              fontSize: 20,
              fontWeight: FontWeight.w700,
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
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: const TextStyle(color: AppColors.muted, fontSize: 12.5),
      ),
    );
  }
}

class CoachRead extends StatelessWidget {
  final String text;

  const CoachRead({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.sky.withValues(alpha: 0.055),
        border: Border.all(color: AppColors.sky.withValues(alpha: 0.28)),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Eyebrow("Coach's read", color: AppColors.sky),
          const SizedBox(height: 8),
          Text(
            text,
            style: const TextStyle(fontSize: 13.5, height: 1.55, color: Color(0xFFCFEAF6)),
          ),
        ],
      ),
    );
  }
}

class LoadingLine extends StatelessWidget {
  final String label;

  const LoadingLine(this.label, {super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(width: 9),
        Text(
          label,
          style: kMono.copyWith(color: AppColors.muted, fontSize: 11),
        ),
      ],
    );
  }
}

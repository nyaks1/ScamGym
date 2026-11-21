import 'package:flutter/material.dart';

import '../theme.dart';

class AppFooter extends StatelessWidget {
  const AppFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final sections = [
          _FooterSection(
            title: 'ScamGym',
            body:
                'A buildathon project. Every scenario uses invented organisations, names and numbers. '
                'Nothing here represents a real bank, agency, courier or retailer.',
          ),
          _FooterSection(
            title: 'Privacy',
            body:
                'Rounds live in server memory only and expire after 45 minutes. No database. '
                'Chat text, links and messages go to the Gemini API for the AI parts, outside South Africa.',
          ),
          _FooterSection(
            title: 'If money has moved',
            body:
                "Call your bank's official fraud line immediately and report the message to the organisation "
                'it pretends to come from. This app is training, not official advice.',
          ),
        ];

        final wide = constraints.maxWidth >= 760;
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 44),
          padding: const EdgeInsets.only(top: 24, bottom: 34),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.lineSoft)),
          ),
          child: wide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < sections.length; i++) ...[
                      if (i > 0) const SizedBox(width: 26),
                      Expanded(child: sections[i]),
                    ],
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < sections.length; i++) ...[
                      if (i > 0) const SizedBox(height: 18),
                      sections[i],
                    ],
                  ],
                ),
        );
      },
    );
  }
}

class _FooterSection extends StatelessWidget {
  final String title;
  final String body;

  const _FooterSection({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: kMonoSmall.copyWith(color: AppColors.muted, letterSpacing: 1.3),
        ),
        const SizedBox(height: 7),
        Text(
          body,
          style: const TextStyle(
            color: AppColors.muted2,
            fontSize: 11.5,
            height: 1.55,
          ),
        ),
      ],
    );
  }
}

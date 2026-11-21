import 'package:flutter/material.dart';

import '../api.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'link_screen.dart';
import 'message_screen.dart';
import 'train_screen.dart';

class HomeShell extends StatefulWidget {
  final ApiClient api;
  final String baseUrl;
  final int epoch;
  final ValueChanged<String> onServerChanged;

  const HomeShell({
    super.key,
    required this.api,
    required this.baseUrl,
    required this.epoch,
    required this.onServerChanged,
  });

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0.9, -1.0),
            radius: 1.2,
            colors: [Color(0x1AB7F36B), Color(0x00070B09)],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              const SimBanner(),
              _Header(
                tab: _tab,
                onTab: (value) => setState(() => _tab = value),
                onServer: _openServerDialog,
              ),
              Expanded(
                child: IndexedStack(
                  index: _tab,
                  children: [
                    TrainScreen(key: ValueKey('train-${widget.epoch}'), api: widget.api),
                    LinkScreen(key: ValueKey('link-${widget.epoch}'), api: widget.api),
                    MessageScreen(key: ValueKey('message-${widget.epoch}'), api: widget.api),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openServerDialog() async {
    final controller = TextEditingController(text: widget.baseUrl);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.panel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppColors.line),
        ),
        title: const Text('Server address'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Leave this blank when the web app is served by the same FastAPI server. '
              'On a phone, use your computer\'s LAN address, for example http://192.168.1.20:8080.',
              style: TextStyle(color: AppColors.muted, fontSize: 12.5, height: 1.5),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              autocorrect: false,
              keyboardType: TextInputType.url,
              style: kMono.copyWith(fontSize: 13),
              decoration: scamInput(hint: 'http://localhost:8080'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(foregroundColor: AppColors.muted),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            style: primaryButtonStyle,
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result != null) widget.onServerChanged(result);
  }
}

class _Header extends StatelessWidget {
  final int tab;
  final ValueChanged<int> onTab;
  final VoidCallback onServer;

  const _Header({
    required this.tab,
    required this.onTab,
    required this.onServer,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 820;
        final brand = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: AppColors.lime.withValues(alpha: 0.42)),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.lime.withValues(alpha: 0.22),
                    AppColors.lime.withValues(alpha: 0.035),
                  ],
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                'SG',
                style: kMono.copyWith(
                  color: AppColors.lime,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'ScamGym',
                  style: TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.8,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Train your instincts. The AI plays the scammer.',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: wide ? 11.5 : 10.5,
                  ),
                ),
              ],
            ),
          ],
        );

        final serverButton = IconButton(
          onPressed: onServer,
          tooltip: 'Server address',
          icon: const Icon(Icons.dns_outlined, size: 19, color: AppColors.muted),
        );

        if (wide) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 12),
            child: Row(
              children: [
                brand,
                const Spacer(),
                _Tabs(tab: tab, onTab: onTab, expanded: false),
                const SizedBox(width: 6),
                serverButton,
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: brand),
                  serverButton,
                ],
              ),
              const SizedBox(height: 12),
              _Tabs(tab: tab, onTab: onTab, expanded: true),
            ],
          ),
        );
      },
    );
  }
}

class _Tabs extends StatelessWidget {
  final int tab;
  final ValueChanged<int> onTab;
  final bool expanded;

  const _Tabs({required this.tab, required this.onTab, required this.expanded});

  @override
  Widget build(BuildContext context) {
    final row = Row(
      mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
      children: [
        _tabButton('Train', 0),
        _tabButton('Check a link', 1),
        _tabButton('Check a message', 2),
      ],
    );
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.panel.withValues(alpha: 0.8),
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(999),
      ),
      child: row,
    );
  }

  Widget _tabButton(String label, int index) {
    final selected = tab == index;
    final child = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onTab(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        padding: EdgeInsets.symmetric(horizontal: expanded ? 8 : 15, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.lime : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: selected ? const Color(0xFF071006) : AppColors.muted,
            fontSize: expanded ? 12 : 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
    return expanded ? Expanded(child: child) : child;
  }
}

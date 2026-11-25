import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
      backgroundColor: AppColors.background,
      body: SafeArea(
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
                  TrainScreen(
                    key: ValueKey('train-${widget.epoch}'),
                    api: widget.api,
                  ),
                  LinkScreen(
                    key: ValueKey('link-${widget.epoch}'),
                    api: widget.api,
                  ),
                  MessageScreen(
                    key: ValueKey('message-${widget.epoch}'),
                    api: widget.api,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openServerDialog() async {
    final controller = TextEditingController(text: widget.baseUrl);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Server address'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Leave this blank when the web app is served by the same FastAPI server. '
              'On a phone, use your computer\'s LAN address, for example http://192.168.1.20:8080.',
              style: TextStyle(
                fontFamily: 'IBMPlexSans',
                color: AppColors.textSecondary,
                fontSize: 14,
                height: 1.43,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              autocorrect: false,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.done,
              onSubmitted: (value) =>
                  Navigator.of(context).pop(value.trim()),
              style: kMono.copyWith(fontSize: 14),
              decoration: scamInput(hint: 'http://localhost:8080'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
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
            ExcludeSemantics(
              child: Container(
                width: 24,
                height: 24,
                color: AppColors.buttonPrimary,
                alignment: Alignment.center,
                child: const Text(
                  'SG',
                  style: TextStyle(
                    fontFamily: 'IBMPlexSans',
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                    height: 1,
                    letterSpacing: 0.16,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'ScamGym',
              style: TextStyle(
                fontFamily: 'IBMPlexSans',
                fontSize: 16,
                height: 1.25,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            if (wide) ...[
              const SizedBox(width: 12),
              Container(width: 1, height: 20, color: AppColors.borderSubtle),
              const SizedBox(width: 12),
              const Text(
                'Scam awareness trainer',
                style: TextStyle(
                  fontFamily: 'IBMPlexSans',
                  fontSize: 12,
                  height: 1.34,
                  color: AppColors.textHelper,
                ),
              ),
            ],
          ],
        );

        final serverButton = IconButton(
          onPressed: onServer,
          tooltip: 'Server address',
          style: ButtonStyle(
            overlayColor: WidgetStateProperty.resolveWith(iconButtonOverlay),
            shape: const WidgetStatePropertyAll(
              RoundedRectangleBorder(borderRadius: BorderRadius.zero),
            ),
            minimumSize: const WidgetStatePropertyAll(Size(40, 40)),
            padding: const WidgetStatePropertyAll(EdgeInsets.zero),
          ),
          icon: const Icon(
            Icons.dns_outlined,
            size: 20,
            color: AppColors.textSecondary,
          ),
        );

        if (wide) {
          return Container(
            height: 48,
            padding: const EdgeInsets.only(left: 16, right: 8),
            decoration: const BoxDecoration(
              color: AppColors.background,
              border: Border(bottom: BorderSide(color: AppColors.borderSubtle)),
            ),
            child: Row(
              children: [
                brand,
                const SizedBox(width: 24),
                _Tabs(
                  tab: tab,
                  onTab: onTab,
                  expanded: false,
                  compact: false,
                  height: 48,
                ),
                const Spacer(),
                serverButton,
              ],
            ),
          );
        }

        return Column(
          children: [
            Container(
              height: 48,
              padding: const EdgeInsets.only(left: 16, right: 8),
              decoration: const BoxDecoration(color: AppColors.background),
              child: Row(children: [brand, const Spacer(), serverButton]),
            ),
            Container(
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: AppColors.borderSubtle),
                  bottom: BorderSide(color: AppColors.borderSubtle),
                ),
              ),
              child: _Tabs(
                tab: tab,
                onTab: onTab,
                expanded: true,
                compact: constraints.maxWidth < 480,
                height: 40,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Tabs extends StatefulWidget {
  final int tab;
  final ValueChanged<int> onTab;
  final bool expanded;
  final bool compact;
  final double height;

  const _Tabs({
    required this.tab,
    required this.onTab,
    required this.expanded,
    required this.compact,
    required this.height,
  });

  @override
  State<_Tabs> createState() => _TabsState();
}

class _TabsState extends State<_Tabs> {
  late final List<FocusNode> _focusNodes = List.generate(
    3,
    (_) => FocusNode(),
  );
  int? _focusedIndex;

  @override
  void dispose() {
    for (final node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _select(int index) {
    widget.onTab(index);
    _focusNodes[index].requestFocus();
  }

  void _move(int delta) {
    final next = (widget.tab + delta + 3) % 3;
    _select(next);
  }

  @override
  Widget build(BuildContext context) {
    final labels = [
      'Train',
      widget.compact ? 'Link' : 'Check a link',
      widget.compact ? 'Message' : 'Check a message',
    ];

    final row = Row(
      mainAxisSize: widget.expanded ? MainAxisSize.max : MainAxisSize.min,
      children: [
        for (var i = 0; i < labels.length; i++) _tabButton(labels[i], i),
      ],
    );

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowRight): () => _move(1),
        const SingleActivator(LogicalKeyboardKey.arrowDown): () => _move(1),
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () => _move(-1),
        const SingleActivator(LogicalKeyboardKey.arrowUp): () => _move(-1),
        const SingleActivator(LogicalKeyboardKey.home): () => _select(0),
        const SingleActivator(LogicalKeyboardKey.end): () => _select(2),
      },
      child: row,
    );
  }

  Widget _tabButton(String label, int index) {
    final selected = widget.tab == index;
    final focused = _focusedIndex == index;
    final child = Material(
      color: Colors.transparent,
      child: InkWell(
        focusNode: _focusNodes[index],
        onFocusChange: (value) {
          if (value) {
            setState(() => _focusedIndex = index);
          } else if (_focusedIndex == index) {
            setState(() => _focusedIndex = null);
          }
        },
        onTap: () => widget.onTab(index),
        hoverColor: AppColors.layerHover,
        splashColor: Colors.transparent,
        highlightColor: AppColors.layerActive,
        child: Container(
          height: widget.height,
          padding: EdgeInsets.symmetric(horizontal: widget.expanded ? 8 : 16),
          alignment: Alignment.center,
          foregroundDecoration: focused
              ? BoxDecoration(
                  border: Border.all(color: AppColors.focus, width: 2),
                )
              : null,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? AppColors.interactive : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Semantics(
            selected: selected,
            inMutuallyExclusiveGroup: true,
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'IBMPlexSans',
                color: selected
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
                fontSize: 14,
                height: 1.29,
                fontWeight: FontWeight.w400,
                letterSpacing: 0.16,
              ),
            ),
          ),
        ),
      ),
    );
    return widget.expanded ? Expanded(child: child) : child;
  }
}

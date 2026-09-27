import 'package:bbarna/resources/app_tokens.dart';
import 'package:bbarna/resources/constant.dart';
import 'package:flutter/material.dart';

/// What a message is telling you. Drives the icon and the accent colour.
enum ToastLevel {
  /// Something you asked for worked.
  success,

  /// Something failed, or you need to fix an input.
  error,

  /// Something happened that is neither. A completed delete is the usual
  /// case: it worked, but it is not a green tick moment.
  info,
}

/// Colour, icon and heading for each [ToastLevel].
extension _ToastLevelStyle on ToastLevel {
  /// Accent colour.
  Color get color => switch (this) {
        ToastLevel.success => const Color(0xFF108460),
        ToastLevel.error => AppTokens.danger,
        ToastLevel.info => const Color(0xFF175CD3),
      };

  /// Leading icon.
  IconData get icon => switch (this) {
        ToastLevel.success => Icons.check_circle_outline,
        ToastLevel.error => Icons.error_outline,
        ToastLevel.info => Icons.info_outline,
      };

  /// Heading shown above the message.
  String get label => switch (this) {
        ToastLevel.success => "Success",
        ToastLevel.error => "Error",
        ToastLevel.info => "Notice",
      };
}

/// One message on screen.
class _ToastData {
  /// Unique id, used to remove exactly this toast.
  final int id;

  /// The text shown.
  final String message;

  /// Controls icon and colour.
  final ToastLevel level;

  const _ToastData(
      {required this.id, required this.message, required this.level});
}

/// Stacked toasts in the corner of the window (full width on phones).
///
/// They stack instead of queueing, dismiss on their own, pause while the
/// pointer is over them, and each has a close button.
class AppToast {
  const AppToast._();

  /// How long a toast stays up when it is left alone.
  static const Duration duration = Duration(seconds: 4);

  /// Beyond this the oldest is dropped, so a loop that reports on every
  /// iteration cannot fill the window.
  static const int maxVisible = 4;

  /// Toasts currently on screen, oldest first.
  static final List<_ToastData> _toasts = <_ToastData>[];

  /// Broadcasts [_toasts] to the overlay so it rebuilds.
  static final ValueNotifier<List<_ToastData>> _notifier =
      ValueNotifier<List<_ToastData>>(const []);

  /// The overlay entry hosting the stack; null while nothing is shown.
  static OverlayEntry? _entry;

  /// Next value for [_ToastData.id].
  static int _nextId = 0;

  /// Visible for tests.
  static List<String> get messages =>
      _toasts.map((toast) => toast.message).toList();

  /// Shows [message] in the corner for [duration] (or until closed).
  /// Does nothing when there is no overlay yet (e.g. unit tests).
  static void show({required String message, required ToastLevel level}) {
    // No overlay yet — the app is between frames, or this is a unit test
    // with no widget tree. Previously this path did
    // `navigatorKey.currentContext!` and threw.
    final OverlayState? overlay = navigatorKey.currentState?.overlay;
    if (overlay == null) return;

    // The same message twice in a row is one event reported twice, not two
    // events. Refresh the one on screen rather than stacking a copy.
    final int existing = _toasts.indexWhere(
        (toast) => toast.message == message && toast.level == level);
    if (existing != -1) {
      final _ToastData current = _toasts.removeAt(existing);
      _toasts.add(_ToastData(
          id: _nextId++, message: current.message, level: current.level));
    } else {
      _toasts.add(_ToastData(id: _nextId++, message: message, level: level));
    }

    while (_toasts.length > maxVisible) {
      _toasts.removeAt(0);
    }

    if (_entry == null) {
      _entry = OverlayEntry(builder: (context) => const _ToastStack());
      overlay.insert(_entry!);
    }
    _publish();
  }

  /// Removes one toast; takes the overlay down when none are left.
  static void _remove(int id) {
    _toasts.removeWhere((toast) => toast.id == id);
    _publish();
    if (_toasts.isEmpty) _dropHost();
  }

  /// Clears everything on screen. Used when the app changes hands — there
  /// is no reason for the previous user's messages to survive a sign-out.
  static void dismissAll() {
    _toasts.clear();
    _publish();
    _dropHost();
  }

  /// Takes the overlay entry down, if it is still in an overlay.
  ///
  /// The guard matters: the tree can go out from under a toast — a
  /// sign-out replaces every route, and a test tears the whole app down —
  /// and `remove()` on an entry whose overlay is already gone asserts.
  static void _dropHost() {
    final OverlayEntry? entry = _entry;
    _entry = null;
    if (entry != null && entry.mounted) entry.remove();
  }

  /// Pushes the current list to [_notifier].
  static void _publish() =>
      _notifier.value = List<_ToastData>.unmodifiable(_toasts);
}

/// The column of toasts in the top-right corner (full width on phones).
class _ToastStack extends StatelessWidget {
  const _ToastStack();

  @override
  Widget build(BuildContext context) {
    final MediaQueryData media = MediaQuery.of(context);
    // Full width on a phone, where a 380px card pinned to one corner
    // would leave almost nothing beside it.
    final bool isNarrow = media.size.width < 560;

    return ValueListenableBuilder<List<_ToastData>>(
      valueListenable: AppToast._notifier,
      builder: (context, toasts, child) {
        if (toasts.isEmpty) return const SizedBox.shrink();

        return Positioned(
          top: media.padding.top + 16,
          right: 16,
          left: isNarrow ? 16 : null,
          child: Align(
            alignment: Alignment.topRight,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final _ToastData toast in toasts)
                  _ToastCard(
                    // Keyed by id so an entry animating in is not reused
                    // for a different message when the list shifts.
                    key: ValueKey<int>(toast.id),
                    data: toast,
                    fullWidth: isNarrow,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// One toast: slides in, counts down with a progress bar, closes itself.
class _ToastCard extends StatefulWidget {
  /// The toast to show.
  final _ToastData data;

  /// True on narrow windows, where the toast spans the width.
  final bool fullWidth;

  const _ToastCard({required this.data, required this.fullWidth, super.key});

  @override
  State<_ToastCard> createState() => _ToastCardState();
}

class _ToastCardState extends State<_ToastCard> with TickerProviderStateMixin {
  /// Slide and fade in, and back out again on the way to being removed.
  late final AnimationController _enter = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 220));

  /// Runs the length of [AppToast.duration]. Doubles as the progress bar,
  /// so the countdown you can see is the countdown that is running.
  late final AnimationController _countdown =
      AnimationController(vsync: this, duration: AppToast.duration);

  /// Set once closing starts, so it only happens once.
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _enter.forward();
    _countdown
      ..addStatusListener(_onCountdown)
      ..forward();
  }

  /// Closes the toast when the countdown finishes.
  void _onCountdown(AnimationStatus status) {
    if (status == AnimationStatus.completed) _close();
  }

  @override
  void dispose() {
    _countdown.removeStatusListener(_onCountdown);
    _enter.dispose();
    _countdown.dispose();
    super.dispose();
  }

  /// Plays the exit animation, then removes the toast.
  Future<void> _close() async {
    if (_closing) return;
    _closing = true;
    _countdown.stop();
    await _enter.reverse();
    if (!mounted) return;
    AppToast._remove(widget.data.id);
  }

  /// Reading a message should not be a race. Web toasts hold while the
  /// pointer is over them; this one holds and shows that it is holding by
  /// freezing its progress bar.
  void _onHover(bool hovering) {
    if (_closing) return;
    if (hovering) {
      _countdown.stop();
    } else {
      _countdown.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ToastLevel level = widget.data.level;

    return FadeTransition(
      opacity: CurvedAnimation(parent: _enter, curve: Curves.easeOut),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.15, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: _enter, curve: Curves.easeOutCubic)),
        child: SizeTransition(
          sizeFactor: CurvedAnimation(parent: _enter, curve: Curves.easeOut),
          axisAlignment: -1,
          child: Padding(
            padding: const EdgeInsets.only(bottom: AppTokens.gapSm),
            child: MouseRegion(
              onEnter: (_) => _onHover(true),
              onExit: (_) => _onHover(false),
              child: Material(
                color: Colors.transparent,
                child: Container(
                  // One width for the whole stack. Sizing each card to its
                  // own text left the close buttons in a different place
                  // on every one.
                  width: widget.fullWidth ? double.infinity : 380,
                  decoration: BoxDecoration(
                    color: AppTokens.surface,
                    borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                    border: Border.all(color: AppTokens.hairline),
                    boxShadow: const [
                      BoxShadow(
                          color: Color(0x1A101828),
                          blurRadius: 16,
                          offset: Offset(0, 6)),
                      BoxShadow(
                          color: Color(0x14101828),
                          blurRadius: 4,
                          offset: Offset(0, 2)),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _body(level),
                        _progressBar(level),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Icon, heading, message and close button.
  Widget _body(ToastLevel level) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 22,
            width: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: level.color.withValues(alpha: .12),
              shape: BoxShape.circle,
            ),
            child: Icon(level.icon, size: 14, color: level.color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  level.label,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                      color: level.color),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.data.message,
                  // Bounded, so one long error cannot grow a card past the
                  // height of the window.
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 13, height: 1.35, color: AppTokens.ink),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          // A visible way to dismiss the toast.
          IconButton(
            key: Key('toast_dismiss_${widget.data.id}'),
            tooltip: "Dismiss",
            onPressed: _close,
            icon: const Icon(Icons.close, size: 15),
            color: AppTokens.inkFaint,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            splashRadius: 16,
          ),
        ],
      ),
    );
  }

  /// How long is left, drawn along the bottom edge. It freezes with the
  /// countdown when the pointer is over the card.
  Widget _progressBar(ToastLevel level) {
    return AnimatedBuilder(
      animation: _countdown,
      builder: (context, child) => Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: (1 - _countdown.value).clamp(0.0, 1.0),
          child: Container(height: 2.5, color: level.color),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import 'branding.dart';
import 'l10n/l10n.dart';

typedef StartupInitializer =
    Future<void> Function(ValueChanged<double> reportProgress);

class StartupCoordinator extends StatefulWidget {
  final StartupInitializer initialize;
  final WidgetBuilder destinationBuilder;
  final Duration minimumPresentationDuration;

  const StartupCoordinator({
    super.key,
    required this.initialize,
    required this.destinationBuilder,
    this.minimumPresentationDuration = const Duration(milliseconds: 2300),
  });

  @override
  State<StartupCoordinator> createState() => _StartupCoordinatorState();
}

class _StartupCoordinatorState extends State<StartupCoordinator>
    with SingleTickerProviderStateMixin {
  double _progress = 0.05;
  double _reportedProgress = 0.05;
  bool _ready = false;
  bool _failed = false;
  late final AnimationController _presentationController;

  @override
  void initState() {
    super.initState();
    _presentationController = AnimationController(
      vsync: this,
      duration: widget.minimumPresentationDuration,
    )..addListener(_updatePresentedProgress);
    _start();
  }

  Future<void> _start() async {
    _presentationController
      ..stop()
      ..reset();
    setState(() {
      _progress = 0.05;
      _reportedProgress = 0.05;
      _ready = false;
      _failed = false;
    });
    final minimumPresentation = _presentationController.forward();
    try {
      await widget
          .initialize((value) {
            if (!mounted || _ready) return;
            _reportedProgress = value.clamp(_reportedProgress, 0.95);
            _updatePresentedProgress();
          })
          .timeout(const Duration(seconds: 25));
      _reportedProgress = 0.95;
      _updatePresentedProgress();
      await minimumPresentation;
      if (!mounted) return;
      setState(() {
        _progress = 1;
        _ready = true;
      });
    } catch (_) {
      _presentationController.stop();
      if (mounted) setState(() => _failed = true);
    }
  }

  void _updatePresentedProgress() {
    if (!mounted || _ready || _failed) return;
    final timeCap =
        0.05 +
        (0.90 * Curves.easeOutCubic.transform(_presentationController.value));
    final nextProgress = _reportedProgress.clamp(_progress, timeCap);
    if (nextProgress > _progress) setState(() => _progress = nextProgress);
  }

  @override
  void dispose() {
    _presentationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 280),
    child: _ready
        ? KeyedSubtree(
            key: const Key('startup-destination'),
            child: widget.destinationBuilder(context),
          )
        : BrandedStartupScreen(
            key: const Key('startup-screen'),
            progress: _progress,
            failed: _failed,
            onRetry: _failed ? _start : null,
          ),
  );
}

class BrandedStartupScreen extends StatefulWidget {
  final double progress;
  final bool failed;
  final VoidCallback? onRetry;

  const BrandedStartupScreen({
    super.key,
    required this.progress,
    this.failed = false,
    this.onRetry,
  });

  @override
  State<BrandedStartupScreen> createState() => _BrandedStartupScreenState();
}

class _BrandedStartupScreenState extends State<BrandedStartupScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
  }

  @override
  void didUpdateWidget(covariant BrandedStartupScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.failed) {
      _controller.stop();
    } else if (oldWidget.failed && !_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Scaffold(
      backgroundColor: padelXBackground,
      body: SafeArea(
        child: Center(
          child: Semantics(
            label: widget.failed
                ? context.l10n.startupFailed
                : context.l10n.startupLoadingSemantics,
            value: '${(widget.progress * 100).round()} percent',
            liveRegion: true,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 36),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 176,
                    height: 176,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (!reduceMotion && !widget.failed)
                          RotationTransition(
                            turns: _controller,
                            child: CircularProgressIndicator(
                              key: const Key('startup-orbit'),
                              value: 0.72,
                              strokeWidth: 2,
                              color: padelXAccent.withValues(alpha: 0.34),
                              backgroundColor: Colors.transparent,
                            ),
                          ),
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.88, end: 1),
                          duration: reduceMotion
                              ? Duration.zero
                              : const Duration(milliseconds: 500),
                          builder: (_, value, child) => Opacity(
                            opacity: value,
                            child: Transform.scale(scale: value, child: child),
                          ),
                          child: const PadelXBrandMark(size: 168),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 34),
                  if (widget.failed) ...[
                    Text(
                      context.l10n.startupFailed,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.l10n.connectionRetry,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 50,
                      child: FilledButton(
                        key: const Key('startup-retry'),
                        onPressed: widget.onRetry,
                        child: Text(context.l10n.tryAgain),
                      ),
                    ),
                  ] else ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        key: const Key('startup-progress'),
                        value: widget.progress,
                        minHeight: 7,
                        color: padelXAccent,
                        backgroundColor: Colors.white12,
                      ),
                    ),
                    const SizedBox(height: 13),
                    ExcludeSemantics(
                      child: Text(
                        context.l10n.loadingPadelX,
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 11,
                          letterSpacing: 3,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';

class AutoHideControlsRegion extends StatefulWidget {
  final Widget controls;
  final Widget body;
  final Widget? divider;
  final Duration hideAfter;

  const AutoHideControlsRegion({
    super.key,
    required this.controls,
    required this.body,
    this.divider,
    this.hideAfter = const Duration(seconds: 4),
  });

  @override
  State<AutoHideControlsRegion> createState() => _AutoHideControlsRegionState();
}

class _AutoHideControlsRegionState extends State<AutoHideControlsRegion> {
  Timer? _timer;
  bool _visible = true;
  bool _controlsHovered = false;
  bool _controlsPressed = false;
  bool _controlsFocused = false;

  @override
  void initState() {
    super.initState();
    _scheduleHide();
  }

  @override
  void didUpdateWidget(covariant AutoHideControlsRegion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.hideAfter != widget.hideAfter) _scheduleHide();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _scheduleHide() {
    _timer?.cancel();
    if (_controlsHovered || _controlsPressed || _controlsFocused) return;
    _timer = Timer(widget.hideAfter, () {
      if (mounted) setState(() => _visible = false);
    });
  }

  void _keepControlsActive() {
    _timer?.cancel();
    if (!_visible && mounted) {
      setState(() => _visible = true);
    }
  }

  void _setControlsHovered(bool value) {
    _controlsHovered = value;
    if (value) {
      _keepControlsActive();
    } else {
      _scheduleHide();
    }
  }

  void _setControlsPressed(bool value) {
    _controlsPressed = value;
    if (value) {
      _keepControlsActive();
    } else {
      _scheduleHide();
    }
  }

  void _setControlsFocused(bool value) {
    _controlsFocused = value;
    if (value) {
      _keepControlsActive();
    } else {
      _scheduleHide();
    }
  }

  void _revealControls() {
    if (!_visible) {
      setState(() => _visible = true);
    }
    _scheduleHide();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _visible ? (_) => _scheduleHide() : null,
      child: Column(
        children: [
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _visible
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Focus(
                        onFocusChange: _setControlsFocused,
                        child: MouseRegion(
                          onEnter: (_) => _setControlsHovered(true),
                          onExit: (_) => _setControlsHovered(false),
                          child: Listener(
                            behavior: HitTestBehavior.translucent,
                            onPointerDown: (_) => _setControlsPressed(true),
                            onPointerUp: (_) => _setControlsPressed(false),
                            onPointerCancel: (_) => _setControlsPressed(false),
                            child: widget.controls,
                          ),
                        ),
                      ),
                      if (widget.divider != null) widget.divider!,
                    ],
                  )
                : const SizedBox.shrink(),
          ),
          Expanded(
            child: Stack(
              children: [
                widget.body,
                if (!_visible)
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: _revealControls,
                      child: const SizedBox.expand(),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

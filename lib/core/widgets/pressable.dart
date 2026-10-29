import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design/haptics.dart';
import '../design/theme.dart';
import '../design/tokens.dart';

/// Grundbaustein für alles Antippbare und Fokussierbare.
///
/// - Touch: leichtes Eindrücken + Haptik.
/// - TV / Tastatur: Fokus per D-Pad, sichtbar durch Skalierung und
///   Akzentrand. Auswahl mit OK/Enter.
///
/// Alle Buttons, Karten und Listeneinträge bauen darauf auf, damit sich die
/// App überall gleich anfühlt.
class LumenPressable extends StatefulWidget {
  const LumenPressable({
    super.key,
    required this.child,
    required this.onPressed,
    this.borderRadius = LumenRadius.mdAll,
    this.focusScale = LumenMotion.focusScale,
    this.autofocus = false,
    this.focusNode,
    this.semanticLabel,
    this.haptic = true,
  });

  final Widget child;
  final VoidCallback? onPressed;
  final BorderRadius borderRadius;
  final double focusScale;
  final bool autofocus;
  final FocusNode? focusNode;
  final String? semanticLabel;
  final bool haptic;

  @override
  State<LumenPressable> createState() => _LumenPressableState();
}

class _LumenPressableState extends State<LumenPressable> {
  bool _focused = false;
  bool _pressed = false;

  bool get _enabled => widget.onPressed != null;

  void _activate() {
    if (!_enabled) return;
    if (widget.haptic) LumenHaptics.selection();
    widget.onPressed!();
  }

  @override
  Widget build(BuildContext context) {
    final lumen = context.lumen;
    final scale = _pressed
        ? LumenMotion.pressScale
        : (_focused ? widget.focusScale : 1.0);

    return Semantics(
      button: true,
      enabled: _enabled,
      label: widget.semanticLabel,
      child: FocusableActionDetector(
        enabled: _enabled,
        autofocus: widget.autofocus,
        focusNode: widget.focusNode,
        mouseCursor:
            _enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.select): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.numpadEnter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.gameButtonA): ActivateIntent(),
        },
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              _activate();
              return null;
            },
          ),
        },
        onShowFocusHighlight: (v) => setState(() => _focused = v),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: _enabled ? (_) => setState(() => _pressed = true) : null,
          onTapCancel: () => setState(() => _pressed = false),
          onTapUp: (_) => setState(() => _pressed = false),
          onTap: _enabled ? _activate : null,
          child: AnimatedScale(
            scale: context.reduceMotion ? 1.0 : scale,
            duration: context.motion(LumenMotion.focus),
            curve: LumenMotion.standard,
            child: AnimatedContainer(
              duration: context.motion(LumenMotion.focus),
              foregroundDecoration: BoxDecoration(
                borderRadius: widget.borderRadius,
                border: Border.all(
                  color: _focused ? lumen.accent : Colors.transparent,
                  width: 3,
                  strokeAlign: BorderSide.strokeAlignOutside,
                ),
              ),
              child: Opacity(
                opacity: _enabled ? 1 : 0.4,
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

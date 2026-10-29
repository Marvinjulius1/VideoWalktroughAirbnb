import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../design/theme.dart';
import '../l10n/app_localizations.dart';
import '../design/tokens.dart';

/// Großes Eingabefeld mit Beschriftung darüber und Inline-Fehler darunter.
///
/// Bei `obscure: true` gibt es einen Knopf zum Ein-/Ausblenden.
class LumenTextField extends StatefulWidget {
  const LumenTextField({
    super.key,
    required this.label,
    this.controller,
    this.hint,
    this.validator,
    this.obscure = false,
    this.keyboardType,
    this.textInputAction = TextInputAction.next,
    this.autofillHints,
    this.onSubmitted,
    this.autofocus = false,
    this.helper,
  });

  final String label;
  final TextEditingController? controller;
  final String? hint;
  final String? helper;
  final FormFieldValidator<String>? validator;
  final bool obscure;
  final TextInputType? keyboardType;
  final TextInputAction textInputAction;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;

  @override
  State<LumenTextField> createState() => _LumenTextFieldState();
}

class _LumenTextFieldState extends State<LumenTextField> {
  late bool _hidden = widget.obscure;

  @override
  Widget build(BuildContext context) {
    final l = context.lumen;
    final p = l.palette;
    OutlineInputBorder border(Color c, [double w = 0]) => OutlineInputBorder(
          borderRadius: LumenRadius.mdAll,
          borderSide:
              w == 0 ? BorderSide.none : BorderSide(color: c, width: w),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: LumenSpace.xxs, bottom: LumenSpace.xs),
          child: Text(widget.label,
              style: l.text.subhead.copyWith(color: p.textSecondary)),
        ),
        TextFormField(
          controller: widget.controller,
          validator: widget.validator,
          obscureText: _hidden,
          autocorrect: false,
          enableSuggestions: !widget.obscure,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          autofillHints: widget.autofillHints,
          onFieldSubmitted: widget.onSubmitted,
          autofocus: widget.autofocus,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          style: l.text.body.copyWith(color: p.textPrimary),
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: l.text.body.copyWith(color: p.textTertiary),
            helperText: widget.helper,
            helperMaxLines: 3,
            helperStyle: l.text.footnote.copyWith(color: p.textSecondary),
            errorMaxLines: 3,
            errorStyle: l.text.footnote.copyWith(color: p.error),
            filled: true,
            fillColor: p.surface2,
            contentPadding: EdgeInsets.symmetric(
              horizontal: LumenSpace.md,
              vertical: l.isTv ? LumenSpace.lg : LumenSpace.md,
            ),
            border: border(p.surface2),
            enabledBorder: border(p.surface2),
            focusedBorder: border(l.accent, 2),
            errorBorder: border(p.error, 1.5),
            focusedErrorBorder: border(p.error, 2),
            suffixIcon: widget.obscure
                ? IconButton(
                    tooltip: _hidden
                        ? AppLocalizations.of(context).showPassword
                        : AppLocalizations.of(context).hidePassword,
                    onPressed: () => setState(() => _hidden = !_hidden),
                    icon: Icon(
                      _hidden
                          ? LucideIcons.eye
                          : LucideIcons.eyeOff,
                      color: p.textSecondary,
                    ),
                  )
                : null,
          ),
        ),
      ],
    );
  }
}

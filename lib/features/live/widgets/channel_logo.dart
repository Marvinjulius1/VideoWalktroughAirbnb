import 'package:flutter/material.dart';

import '../../../core/design/theme.dart';
import '../../../core/design/tokens.dart';

/// Senderlogo auf ruhiger Fläche. Ohne (ladbares) Logo: Initialen.
///
/// Logos werden in Anzeigegröße dekodiert (`cacheWidth`), damit tausende
/// Logos den Speicher nicht sprengen.
class ChannelLogo extends StatelessWidget {
  const ChannelLogo({super.key, required this.name, this.url, this.width = 64, this.height = 44});

  final String name;
  final String? url;
  final double width;
  final double height;

  static String initials(String name) {
    final words = name
        .replaceAll(RegExp(r'[^\p{L}\p{N} ]', unicode: true), ' ')
        .split(' ')
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return '?';
    if (words.length == 1) return words.first.characters.take(2).toString().toUpperCase();
    return (words[0].characters.first + words[1].characters.first).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.lumen;
    final p = l.palette;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final fallback = Center(
      child: Text(
        initials(name),
        style: l.text.subhead.copyWith(color: p.textSecondary, fontWeight: FontWeight.w600),
      ),
    );
    return ExcludeSemantics(
      child: Container(
        width: width,
        height: height,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: p.surface2, borderRadius: LumenRadius.smAll),
        child: url == null
            ? fallback
            : Image.network(
                url!,
                fit: BoxFit.contain,
                cacheWidth: (width * dpr).round(),
                gaplessPlayback: true,
                errorBuilder: (_, _, _) => fallback,
                frameBuilder: (_, child, frame, sync) => sync || frame != null
                    ? child
                    : fallback,
              ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../theme/s4_theme.dart';

/// The about tab: one card, exactly the words the preview ships.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final S4Palette palette = paletteOf(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 10, 22, 24),
      children: <Widget>[
        const Text(
          'درباره ما',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, height: 1.4),
        ),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: palette.line),
            color: palette.card,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'SOFT400',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                'امیدوارم بتونید بشترین دورزدن تحریم و فیلتر رو باهم انجام بدین و کسی فیلتر نشه',
                style: TextStyle(fontSize: 13, color: palette.mute, height: 2),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

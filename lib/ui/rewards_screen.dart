import 'package:flutter/material.dart';

import '../models/rewards.dart';
import '../state/app_state.dart';
import '../theme/s4_theme.dart';
import 'app_scope.dart';

/// The rewards tab: watch an ad for connections, or spend a code on time.
///
/// The tab is not in the navigation at all while a code is running, so there
/// is nothing here to say "premium" -- the absence of the tab is the message.
class RewardsScreen extends StatefulWidget {
  const RewardsScreen({super.key});

  @override
  State<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends State<RewardsScreen> {
  final TextEditingController _code = TextEditingController();
  bool _checking = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final S4Palette palette = paletteOf(context);

    return ListenableBuilder(
      listenable: state,
      builder: (BuildContext context, Widget? _) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(22, 10, 22, 24),
          children: <Widget>[
            Text(
              state.tr('جایزه و امتیاز'),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, height: 1.4),
            ),
            const SizedBox(height: 14),
            _BalanceCard(palette: palette),
            const SizedBox(height: 12),
            _WatchCard(palette: palette),
            const SizedBox(height: 12),
            _CodeCard(
              palette: palette,
              controller: _code,
              checking: _checking,
              onSubmit: _submit,
            ),
            const SizedBox(height: 12),
            _HistoryCard(palette: palette),
          ],
        );
      },
    );
  }

  Future<void> _submit() async {
    final AppState state = AppScope.of(context);
    setState(() => _checking = true);
    final bool ok = await state.redeemCode(_code.text);
    if (!mounted) return;
    setState(() => _checking = false);
    if (ok) _code.clear();
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.palette});

  final S4Palette palette;

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.line),
        color: palette.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            state.tr('اتصال‌های باقی‌مانده'),
            style: TextStyle(fontSize: 13, color: palette.mute),
          ),
          const SizedBox(height: 6),
          Text(
            state.fa(state.credits),
            textDirection: TextDirection.ltr,
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w800,
              color: palette.neon,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            state.tr('هر تبلیغ ${state.fa(RewardState.connectionsPerAd)} اتصال می‌دهد؛ امتیاز محدود به زمان نیست.'),
            style: TextStyle(fontSize: 12, color: palette.mute, height: 1.7),
          ),
        ],
      ),
    );
  }
}

class _WatchCard extends StatelessWidget {
  const _WatchCard({required this.palette});

  final S4Palette palette;

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.line),
        color: palette.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            state.tr('دیدن تبلیغ'),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            state.tr('با دیدن هر تبلیغ چند اتصال آزاد می‌شود.'),
            style: TextStyle(fontSize: 12, color: palette.mute, height: 1.7),
          ),
          const SizedBox(height: 12),
          Material(
            color: palette.blue,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: state.watchingAd ? null : state.watchAd,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 13),
                child: Center(
                  child: Text(
                    state.watchingAd
                        ? state.tr('در حال تماشا…')
                        : state.tr('تماشای تبلیغ'),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CodeCard extends StatelessWidget {
  const _CodeCard({
    required this.palette,
    required this.controller,
    required this.checking,
    required this.onSubmit,
  });

  final S4Palette palette;
  final TextEditingController controller;
  final bool checking;
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.line),
        color: palette.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            state.tr('کد فعال‌سازی'),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            state.tr('کد را وارد کنید تا سرور مدت آن را بررسی کند.'),
            style: TextStyle(fontSize: 12, color: palette.mute, height: 1.7),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            textDirection: TextDirection.ltr,
            style: TextStyle(fontFamily: kMonoFont, fontSize: 14, color: palette.ink),
            decoration: InputDecoration(
              hintText: 'XXXX-XXXX',
              hintStyle: TextStyle(
                fontFamily: kMonoFont,
                fontSize: 14,
                color: palette.mute.withValues(alpha: 0.7),
              ),
              filled: true,
              fillColor: palette.fieldBackground,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: palette.line),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: palette.blue, width: 1.4),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Material(
            color: palette.card,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: checking ? null : onSubmit,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: palette.line),
                ),
                child: Center(
                  child: Text(
                    checking ? state.tr('در حال بررسی…') : state.tr('بررسی کد'),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: palette.ink,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.palette});

  final S4Palette palette;

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final List<RewardTransaction> history = state.rewards.history;
    if (history.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: palette.line),
          color: palette.card,
        ),
        child: Text(
          state.tr('هنوز چیزی ثبت نشده.'),
          style: TextStyle(fontSize: 12, color: palette.mute),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.line),
        color: palette.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            state.tr('تاریخچه'),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          for (final RewardTransaction entry in history.take(12))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: <Widget>[
                  Icon(
                    entry.source == CreditSource.ad
                        ? Icons.play_circle_outline
                        : Icons.card_giftcard_outlined,
                    size: 16,
                    color: palette.mute,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      entry.source == CreditSource.ad
                          ? state.tr('تبلیغ')
                          : state.tr('کد'),
                      style: TextStyle(fontSize: 13, color: palette.ink),
                    ),
                  ),
                  Text(
                    state.fa(entry.amount),
                    textDirection: TextDirection.ltr,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: entry.amount >= 0 ? palette.teal : palette.amber,
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

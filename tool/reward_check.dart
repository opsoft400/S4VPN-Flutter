// Checks the reward model without a Flutter engine, so the rules can be
// verified where the test runner will not start.
import 'dart:io';

import 'package:s4vpn/models/rewards.dart';

void main() {
  var failures = 0;
  void check(String what, bool ok) {
    stdout.writeln('  ${ok ? 'ok  ' : 'FAIL'} $what');
    if (!ok) failures++;
  }

  check('one ad buys three connections', RewardState.connectionsPerAd == 3);

  final RewardState state = RewardState();
  check('a fresh balance cannot pay', !state.canAffordConnection);
  check('a fresh balance is not free', !state.adFreeActive);

  state.add(source: CreditSource.ad, amount: RewardState.connectionsPerAd);
  check('an ad fills the balance', state.credits == 3);
  check('the balance can now pay', state.canAffordConnection);
  check('the total earned is counted', state.totalEarned == 3);

  check('a connection can be paid for', state.spendOne());
  check('the balance went down', state.credits == 2);
  check('the total spent is counted', state.totalSpent == 1);

  state.grantAdFree(const Duration(hours: 2));
  check('a code switches the balance off', state.adFreeActive);
  check('the remaining time is shown', state.adFreeRemainingLabel.isNotEmpty);
  check('a code does not touch the balance', state.credits == 2);

  final RewardState expired = RewardState();
  expired.grantAdFree(const Duration(seconds: -1));
  check('an expired code does nothing', !expired.adFreeActive);

  stdout.writeln(failures == 0 ? '\nall reward checks passed' : '\n$failures failed');
  if (failures > 0) exit(1);
}

// Runs the pure-Dart logic without flutter_test, so the parts that matter are
// checked even where the test runner of a hand-assembled SDK will not start.
import 'dart:io';

import 'package:s4vpn/engine/engine_mode.dart';
import 'package:s4vpn/engine/plan.dart';
import 'package:s4vpn/l10n/translator.dart';
import 'package:s4vpn/models/vpn_config.dart';

int failures = 0;

void check(String what, bool ok, [String? detail]) {
  if (!ok) {
    failures++;
    stdout.writeln('  FAIL $what ${detail ?? ''}');
  } else {
    stdout.writeln('  ok   $what');
  }
}

void main() {
  Translator.prime();

  stdout.writeln('translator');
  check('fa passes through', Translator.tr('خانه', 'fa') == 'خانه');
  check('fa -> en whole phrase',
      Translator.tr('آماده اتصال', 'en') == 'Ready to connect');
  check('fa -> en by parts', Translator.tr('اتصال', 'en') == 'Connect');
  check('fa -> zh', Translator.tr('خانه', 'zh') == '主页');
  check('fa -> ru', Translator.tr('خانه', 'ru') == 'Главная');
  check('chrome per language',
      Translator.chrome('home', 'fa') == 'خانه' &&
          Translator.chrome('home', 'de') == 'Startseite');
  check('chrome fallback', Translator.chrome('nope', 'ja') == 'nope');
  check('digits', Translator.faDigits(48) == '۴۸');

  stdout.writeln('config');
  final VpnConfig cfg = VpnConfig.defaults();
  check('engine default', cfg.textOf('engine') == 'aether');
  check('bind default', cfg.textOf('bind') == '127.0.0.1:1819');
  check('dns default', cfg.textOf('dns') == '1.1.1.1,1.0.0.1');
  final VpnConfig copy = VpnConfig.from(cfg)..set('engine', 'tor');
  check('copy does not alias', copy.textOf('engine') == 'tor');

  stdout.writeln('engine plans');
  EnginePlan plan = buildPlan(cfg);
  check('aether runs one core', plan.processes.length == 1);
  check('aether core is aether', plan.processes.first.core == CoreId.aether);
  check('aether binds the configured port', plan.socksPort == 1819);
  check('aether passes --bind',
      plan.processes.first.args.contains('--bind'));
  check('aether route', plan.routeNodes.first == 'شما');

  final VpnConfig tor = VpnConfig.defaults()..set('engine', 'tor');
  plan = buildPlan(tor);
  check('tor-only runs one core', plan.processes.length == 1);
  check('tor-only says so',
      plan.processes.first.args.contains('--tor-only'));
  check('tor-only strips the warp scan',
      !plan.processes.first.args.contains('--scan'));

  final VpnConfig torChain = VpnConfig.defaults()
    ..set('engine', 'tor')
    ..set('torWay', 'chain');
  plan = buildPlan(torChain);
  check('tor chain keeps warp', plan.processes.first.args.contains('--scan'));
  check('tor chain carries tor', plan.processes.first.args.contains('--tor'));

  final VpnConfig psiphon = VpnConfig.defaults()
    ..set('engine', 'psiphon')
    ..set('psWay', 'chain');
  plan = buildPlan(psiphon);
  check('psiphon chain runs two cores', plan.processes.length == 2);
  check('psiphon chain hops psiphon then aether',
      plan.processes[0].core == CoreId.psiphon &&
          plan.processes[1].core == CoreId.aether);
  check('psiphon chain dials through psiphon',
      plan.processes[1].args.contains('--upstream'));

  final VpnConfig psiphonOnly = VpnConfig.defaults()
    ..set('engine', 'psiphon')
    ..set('psWay', 'only');
  plan = buildPlan(psiphonOnly);
  check('psiphon only runs one core', plan.processes.length == 1);
  check('psiphon only owns the bind port', plan.socksPort == 1819);

  final VpnConfig s4 = VpnConfig.defaults()..set('engine', 's4');
  plan = buildPlan(s4);
  check('s4 runs lantern', plan.processes.first.core == CoreId.lantern);
  check('s4 steps name S4VPN', plan.stepLabels.first == 'دریافت پیکربندی S4VPN');

  stdout.writeln('');
  if (failures == 0) {
    stdout.writeln('all checks passed');
  } else {
    stdout.writeln('$failures check(s) failed');
    exit(1);
  }
}

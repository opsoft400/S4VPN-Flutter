import 'package:flutter/material.dart';

import 'app.dart';
import 'l10n/translator.dart';
import 'state/app_state.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // The translation tables are one long first lookup each; warming them here
  // keeps the first frame from paying for them.
  Translator.prime();
  runApp(S4VpnApp(state: AppState()));
}

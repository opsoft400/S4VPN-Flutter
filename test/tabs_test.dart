
import 'package:flutter_test/flutter_test.dart';
import 'package:s4vpn/app.dart';
import 'package:s4vpn/state/app_state.dart';

/// The navigation and the screens behind it have to agree on which tabs
/// exist: the nav bar draws a label for every tab, and the strip behind it
/// draws a screen for every tab. If the two ever count differently the last
/// screen is drawn under the wrong label.
void main() {
  testWidgets('the rewards tab appears while no code is running', (
    WidgetTester tester,
  ) async {
    final AppState state = AppState();
    await tester.pumpWidget(S4VpnApp(state: state));
    await tester.pump();

    expect(find.text('جایزه'), findsOneWidget);
  });

  testWidgets('the rewards tab is gone while a code is running', (
    WidgetTester tester,
  ) async {
    final AppState state = AppState();
    state.rewards.grantAdFree(const Duration(hours: 1));
    await tester.pumpWidget(S4VpnApp(state: state));
    await tester.pump();

    expect(find.text('جایزه'), findsNothing);
  });

  testWidgets('the home screen still shows the engine picker', (
    WidgetTester tester,
  ) async {
    final AppState state = AppState();
    await tester.pumpWidget(S4VpnApp(state: state));
    await tester.pump();

    expect(find.text('aether'), findsOneWidget);
    expect(find.text('Psiphon'), findsOneWidget);
  });
}

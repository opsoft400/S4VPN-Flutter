import 'package:flutter/widgets.dart';

import '../state/app_state.dart';

/// Puts the single [AppState] within reach of every screen.
///
/// One notifier, one rebuild path: widgets that care call [AppScope.of] and
/// listen to what it returns, so a change to the config and a change to the
/// connection state reach the same frame.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
      : super(notifier: state);

  static AppState of(BuildContext context) {
    final AppScope? scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope is missing above this widget');
    return scope!.notifier!;
  }

  /// Read without subscribing, for callbacks that only mutate.
  static AppState read(BuildContext context) {
    final AppScope? scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    return scope!.notifier!;
  }
}

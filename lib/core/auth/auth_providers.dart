// lib/core/auth/auth_providers.dart
import 'package:riverpod/riverpod.dart';                 // core Riverpod v3
import 'package:supabase_flutter/supabase_flutter.dart';

/// Stream of auth state; rebuilds on login/logout.
final authStateProvider = StreamProvider<AuthState>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange;
});

/// Convenience computed: are we signed in right now?
final isSignedInProvider = Provider<bool>((ref) {
  final session = Supabase.instance.client.auth.currentSession;
  return session != null;
});

/// What the user tried to do while logged out.
abstract class PendingAction {
  const PendingAction();
}

class PendingBook extends PendingAction {
  final String vehicleTypeId;
  const PendingBook(this.vehicleTypeId);
}

/// ---- Notifier for pending action (null when nothing is pending)
class _PendingActionNotifier extends Notifier<PendingAction?> {
  @override
  PendingAction? build() => null;

  void set(PendingAction? action) => state = action;
}

final pendingActionProvider = NotifierProvider<_PendingActionNotifier, PendingAction?>(
  _PendingActionNotifier.new,
);

/// ---- Notifier for current tab
enum AppTab { rides, results, account }

class _CurrentTabNotifier extends Notifier<AppTab> {
  @override
  AppTab build() => AppTab.rides;

  void set(AppTab tab) => state = tab;
}

final currentTabProvider = NotifierProvider<_CurrentTabNotifier, AppTab>(
  _CurrentTabNotifier.new,
);

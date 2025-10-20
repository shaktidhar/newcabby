// lib/features/account/presentation/account_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/auth/auth_providers.dart';

class AccountPage extends ConsumerWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = ref.watch(isSignedInProvider);
    final pending = ref.watch(pendingActionProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: signedIn
          ? _SignedInView(
        showContinue: pending is PendingBook,
        onContinuePending: () {
          final pa = ref.read(pendingActionProvider);
          if (pa is PendingBook) {
            // Clear pending action and switch back to Results tab.
            ref.read(pendingActionProvider.notifier).set(null);
            ref.read(currentTabProvider.notifier).set(AppTab.results);
          }
        },
      )
          : const _AuthForm(),
    );
  }
}

class _SignedInView extends StatelessWidget {
  final bool showContinue;
  final VoidCallback onContinuePending;
  const _SignedInView({
    required this.showContinue,
    required this.onContinuePending,
  });

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ListTile(
          leading: const Icon(Icons.person),
          title: Text(user?.email ?? 'Signed in'),
          subtitle: const Text('You are signed in'),
        ),
        if (showContinue)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: FilledButton.icon(
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Continue booking'),
              onPressed: onContinuePending,
            ),
          ),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: () async {
            await Supabase.instance.client.auth.signOut();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Signed out')),
              );
            }
          },
          child: const Text('Sign out'),
        ),
      ],
    );
  }
}

class _AuthForm extends ConsumerStatefulWidget {
  const _AuthForm();

  @override
  ConsumerState<_AuthForm> createState() => _AuthFormState();
}

class _AuthFormState extends ConsumerState<_AuthForm> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _busy = false;
  String? _error;
  bool _isRegister = false;

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          _isRegister ? 'Create account' : 'Log in',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          decoration: const InputDecoration(
            labelText: 'Email',
            prefixIcon: Icon(Icons.email_outlined),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _pass,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Password',
            prefixIcon: Icon(Icons.lock_outline),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: const TextStyle(color: Colors.red)),
        ],
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _busy
              ? null
              : () async {
            setState(() {
              _busy = true;
              _error = null;
            });
            try {
              final auth = Supabase.instance.client.auth;
              if (_isRegister) {
                await auth.signUp(
                  email: _email.text.trim(),
                  password: _pass.text,
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Account created. You can log in now.')),
                  );
                }
                setState(() => _isRegister = false);
              } else {
                await auth.signInWithPassword(
                  email: _email.text.trim(),
                  password: _pass.text,
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Welcome back!')),
                  );
                }
              }
            } catch (e) {
              setState(() => _error = e.toString());
            } finally {
              if (mounted) setState(() => _busy = false);
            }
          },
          child: _busy
              ? const SizedBox(
            height: 18,
            width: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
              : Text(_isRegister ? 'Register' : 'Log in'),
        ),
        TextButton(
          onPressed: _busy ? null : () => setState(() => _isRegister = !_isRegister),
          child: Text(_isRegister ? 'I already have an account' : 'Create an account'),
        ),
      ],
    );
  }
}

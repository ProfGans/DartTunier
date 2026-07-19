import 'package:flutter/material.dart';

import '../../application/account_session_store.dart';
import '../../data/supabase_account_config.dart';
import '../../data/supabase_account_session_store.dart';
import '../../../tournaments/data/app_database.dart';
import '../../domain/account_user.dart';

class AccountMenuCard extends StatefulWidget {
  const AccountMenuCard({
    super.key,
    LocalAppDatabase? database,
    AccountSessionStore? store,
  }) : _database = database,
       _store = store;

  final LocalAppDatabase? _database;
  final AccountSessionStore? _store;

  @override
  State<AccountMenuCard> createState() => _AccountMenuCardState();
}

class _AccountMenuCardState extends State<AccountMenuCard> {
  late final AccountSessionStore _store;
  late Future<AccountUser?> _accountFuture;

  @override
  void initState() {
    super.initState();
    _store =
        widget._store ??
        (SupabaseAccountConfig.isConfigured
            ? SupabaseAccountSessionStore()
            : LocalAccountSessionStore(widget._database ?? LocalAppDatabase()));
    _accountFuture = _store.loadCurrentAccount();
  }

  void _reloadAccount() {
    setState(() {
      _accountFuture = _store.loadCurrentAccount();
    });
  }

  Future<void> _openSignInDialog() async {
    final result = await showDialog<_AccountFormResult>(
      context: context,
      builder: (context) => const _AccountDialog(mode: _AccountDialogMode.signIn),
    );
    if (result == null) {
      return;
    }

    final account = await _runAccountAction<AccountUser?>(
      () => _store.signInAccount(
        email: result.email,
        password: result.password,
      ),
    );
    if (!mounted) {
      return;
    }
    if (account == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kein Account mit dieser E-Mail gefunden.')),
      );
      return;
    }

    _reloadAccount();
  }

  Future<void> _openRegisterDialog() async {
    final result = await showDialog<_AccountFormResult>(
      context: context,
      builder: (context) => const _AccountDialog(
        mode: _AccountDialogMode.register,
      ),
    );
    if (result == null) {
      return;
    }

    await _runAccountAction<void>(
      () => _store.registerAccount(
        displayName: result.displayName,
        email: result.email,
        password: result.password,
        country: result.country,
        city: result.city,
        dartsSetup: result.dartsSetup,
      ),
    );
    if (!mounted) {
      return;
    }
    _reloadAccount();
  }

  Future<void> _signOut() async {
    await _store.signOutCurrentAccount();
    if (!mounted) {
      return;
    }
    _reloadAccount();
  }

  Future<T?> _runAccountAction<T>(Future<T> Function() action) async {
    try {
      return await action();
    } catch (error) {
      if (!mounted) {
        return null;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_accountErrorMessage(error))),
      );
      return null;
    }
  }

  String _accountErrorMessage(Object error) {
    final message = error.toString();
    if (message.contains('AuthException')) {
      return message
          .replaceFirst('AuthException(message: ', '')
          .replaceFirst(')', '');
    }
    return 'Account-Aktion fehlgeschlagen: $message';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AccountUser?>(
      future: _accountFuture,
      builder: (context, snapshot) {
        final account = snapshot.data;
        if (account == null) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.account_circle_outlined),
                    title: Text('Account'),
                    subtitle: Text('Nicht angemeldet'),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      _store.signInLabel,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      TextButton.icon(
                        onPressed: _openSignInDialog,
                        icon: const Icon(Icons.login_outlined),
                        label: const Text('Anmelden'),
                      ),
                      FilledButton.icon(
                        onPressed: _openRegisterDialog,
                        icon: const Icon(Icons.person_add_alt_1_outlined),
                        label: const Text('Account erstellen'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }

        return Card(
          child: ListTile(
            leading: CircleAvatar(child: Text(account.initials)),
            title: Text(account.displayName),
            subtitle: Text(account.email),
            trailing: IconButton(
              onPressed: _signOut,
              icon: const Icon(Icons.logout_outlined),
              tooltip: 'Abmelden',
            ),
          ),
        );
      },
    );
  }
}

enum _AccountDialogMode { signIn, register }

class _AccountDialog extends StatefulWidget {
  const _AccountDialog({required this.mode});

  final _AccountDialogMode mode;

  @override
  State<_AccountDialog> createState() => _AccountDialogState();
}

class _AccountDialogState extends State<_AccountDialog> {
  final _displayNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _countryController = TextEditingController();
  final _cityController = TextEditingController();
  final _dartsSetupController = TextEditingController();
  String? _errorText;

  bool get _isRegister => widget.mode == _AccountDialogMode.register;

  @override
  void dispose() {
    _displayNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _countryController.dispose();
    _cityController.dispose();
    _dartsSetupController.dispose();
    super.dispose();
  }

  void _submit() {
    final displayName = _displayNameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (_isRegister && displayName.isEmpty) {
      setState(() {
        _errorText = 'Bitte gib einen Namen ein.';
      });
      return;
    }
    if (!email.contains('@') || !email.contains('.')) {
      setState(() {
        _errorText = 'Bitte gib eine gueltige E-Mail ein.';
      });
      return;
    }
    if (password.length < 6) {
      setState(() {
        _errorText = 'Das Passwort braucht mindestens 6 Zeichen.';
      });
      return;
    }

    Navigator.of(context).pop(
      _AccountFormResult(
        displayName: displayName,
        email: email,
        password: password,
        country: _countryController.text.trim(),
        city: _cityController.text.trim(),
        dartsSetup: _dartsSetupController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = _isRegister ? 'Account erstellen' : 'Anmelden';

    return AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isRegister) ...[
              TextField(
                controller: _displayNameController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                textInputAction: TextInputAction.next,
                autofocus: true,
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'E-Mail',
                prefixIcon: Icon(Icons.email_outlined),
              ),
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              autofocus: !_isRegister,
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Passwort',
                prefixIcon: Icon(Icons.lock_outline),
              ),
              obscureText: true,
              textInputAction: _isRegister
                  ? TextInputAction.next
                  : TextInputAction.done,
              onSubmitted: (_) {
                if (!_isRegister) {
                  _submit();
                }
              },
            ),
            if (_isRegister) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _countryController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Land',
                  prefixIcon: Icon(Icons.flag_outlined),
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _cityController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Stadt',
                  prefixIcon: Icon(Icons.location_city_outlined),
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _dartsSetupController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Dart-Setup',
                  prefixIcon: Icon(Icons.sports_bar_outlined),
                ),
                onSubmitted: (_) => _submit(),
              ),
            ],
            if (_errorText != null) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _errorText!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(title),
        ),
      ],
    );
  }
}

class _AccountFormResult {
  const _AccountFormResult({
    required this.displayName,
    required this.email,
    required this.password,
    required this.country,
    required this.city,
    required this.dartsSetup,
  });

  final String displayName;
  final String email;
  final String password;
  final String country;
  final String city;
  final String dartsSetup;
}

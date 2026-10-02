import 'dart:async';
import '../../../league/presentation/league_invitation_listener.dart';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import '../../data/scorer_lobby_repository.dart';
import '../../domain/scorer_lobby.dart';
import 'scorer_join_page.dart';

/// Inbox pop-ups while the app is open; links also work on cold starts.
class ScorerInvitationListener extends StatefulWidget {
  const ScorerInvitationListener({
    super.key,
    required this.navigatorKey,
    required this.child,
    this.repository,
    this.links,
    this.initialLink,
  });
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;
  final ScorerLobbyRepository? repository;
  final Stream<Uri>? links;
  final Future<Uri?>? initialLink;
  @override
  State<ScorerInvitationListener> createState() =>
      _ScorerInvitationListenerState();
}

class _ScorerInvitationListenerState extends State<ScorerInvitationListener>
    with WidgetsBindingObserver {
  late final repository = widget.repository ?? ScorerLobbyRepository();
  Timer? timer;
  StreamSubscription<Uri>? links;
  bool busy = false, active = true;
  final seen = <String>{};
  final openCodes = <String>{};
  String? account;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    links = (widget.links ?? AppLinks().uriLinkStream).listen(
      _link,
      onError: (Object _) {},
    );
    _initialLink();
    timer = Timer.periodic(const Duration(seconds: 8), (_) => _poll());
    WidgetsBinding.instance.addPostFrameCallback((_) => _poll());
  }

  Future<void> _initialLink() async {
    try {
      final uri =
          await (widget.initialLink ??
              (widget.links == null
                  ? AppLinks().getInitialLink()
                  : Future<Uri?>.value()));
      if (uri != null && mounted) _link(uri);
    } catch (_) {
      /* Link handler not installed on every platform. */
    }
  }

  void _link(Uri uri) {
    final code = ScorerJoinCode.parse(uri.toString());
    if (code == null || !openCodes.add(code)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted) {
        await widget.navigatorKey.currentState?.push(
          MaterialPageRoute<void>(builder: (_) => ScorerJoinPage(code: code)),
        );
      }
      openCodes.remove(code);
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    active = state == AppLifecycleState.resumed;
    if (active) _poll();
  }

  Future<void> _poll() async {
    if (busy || !mounted || !active) return;
    final user = repository.userId;
    if (user != account) {
      account = user;
      seen.clear();
    }
    if (user == null) return;
    busy = true;
    try {
      final invitations = await repository.invitations();
      if (!mounted || !active || repository.userId != user) return;
      for (final invitation in invitations) {
        if (seen.contains(invitation.id)) continue;
        final context = widget.navigatorKey.currentState?.overlay?.context;
        if (context == null || !context.mounted) return;
        await showDialog<bool>(
          context: context,
          builder: (_) => _InvitationDialog(
            invitation: invitation,
            repository: repository,
            userId: user,
          ),
        );
        if (!mounted || repository.userId != user) return;
        seen.add(invitation.id);
        break;
      }
    } catch (_) {
      /* Offline or migration pending: retry on next inbox poll. */
    } finally {
      busy = false;
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    links?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LeagueInvitationListener(navigatorKey: widget.navigatorKey, child: widget.child);
}

class _InvitationDialog extends StatefulWidget {
  const _InvitationDialog({
    required this.invitation,
    required this.repository,
    required this.userId,
  });
  final ScorerInvitation invitation;
  final ScorerLobbyRepository repository;
  final String userId;
  @override
  State<_InvitationDialog> createState() => _InvitationDialogState();
}

class _InvitationDialogState extends State<_InvitationDialog> {
  bool busy = false;
  String? error;
  Future<void> _answer(bool accept) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (widget.repository.userId != widget.userId) {
        throw StateError('Konto gewechselt');
      }
      await widget.repository.respond(widget.invitation.id, accept);
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'Antwort nicht möglich. Verbindung prüfen; möglicherweise ist das Spiel bereits gestartet.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: AlertDialog(
      title: const Text('Einladung zum Scorer'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${widget.invitation.hostName} lädt dich zum gemeinsamen Spiel am Board ein. Bei Annahme wird dein Konto zur Teilnehmerliste hinzugefügt.',
            ),
            if (error != null) Text(error!),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => _answer(false),
          child: const Text('Ablehnen'),
        ),
        FilledButton(
          onPressed: busy ? null : () => _answer(true),
          child: Text(busy ? 'Wird bestätigt …' : 'Mitspielen'),
        ),
      ],
    ),
  );
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/tournament_access_repository.dart';
import '../../domain/tournament_access.dart';
import '../../domain/tournament_models.dart';

class TournamentAccessGate extends StatefulWidget {
  const TournamentAccessGate({
    super.key,
    required this.tournament,
    required this.builder,
    this.load,
  });
  final CreatedTournament tournament;
  final Widget Function(BuildContext, TournamentAccess) builder;
  final Future<TournamentAccess> Function()? load;
  @override
  State<TournamentAccessGate> createState() => _TournamentAccessGateState();
}

class _TournamentAccessGateState extends State<TournamentAccessGate> {
  late Future<TournamentAccess> _access = _load();
  StreamSubscription<AuthState>? _auth;
  Future<TournamentAccess> _load() =>
      widget.load?.call() ??
      TournamentAccessRepository().load(widget.tournament);
  @override
  void initState() {
    super.initState();
    if (widget.tournament.communityId != null) {
      try {
        _auth = Supabase.instance.client.auth.onAuthStateChange.listen((_) {
          if (mounted) setState(() => _access = _load());
        });
      } catch (_) {
        /* No authenticated backend in local previews. */
      }
    }
  }

  @override
  void didUpdateWidget(covariant TournamentAccessGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tournament != widget.tournament ||
        oldWidget.load != widget.load) {
      _access = _load();
    }
  }

  @override
  void dispose() {
    _auth?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.tournament.communityId == null) {
      return widget.builder(context, TournamentAccess.local);
    }
    return FutureBuilder<TournamentAccess>(
      future: _access,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            snapshot.hasData) {
          return widget.builder(context, snapshot.data!);
        }
        return Scaffold(
          appBar: AppBar(title: Text(widget.tournament.name)),
          body: Center(
            child: snapshot.connectionState != ConnectionState.done
                ? const CircularProgressIndicator()
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Turnierrechte konnten nicht geladen werden.'),
                      TextButton(
                        onPressed: () => setState(() => _access = _load()),
                        child: const Text('Erneut versuchen'),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }
}

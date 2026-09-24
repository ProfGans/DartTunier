import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/widgets.dart';
import '../../features/communities/domain/community_invitation.dart';

/// Handles cold starts and links delivered while the application is running.
class CommunityLinkListener extends StatefulWidget {
  const CommunityLinkListener({
    super.key,
    required this.child,
    required this.onInvitation,
    this.links,
    this.initialLink,
  });
  final Widget child;
  final Future<void> Function(String code) onInvitation;
  final Stream<Uri>? links;
  final Future<Uri?>? initialLink;

  @override
  State<CommunityLinkListener> createState() => _CommunityLinkListenerState();
}

class _CommunityLinkListenerState extends State<CommunityLinkListener> {
  StreamSubscription<Uri>? _subscription;
  final _openCodes = <String>{};

  @override
  void initState() {
    super.initState();
    _subscription = (widget.links ?? AppLinks().uriLinkStream).listen(
      _receive,
      onError: (Object _) {},
    );
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    try {
      final uri =
          await (widget.initialLink ??
              (widget.links == null
                  ? AppLinks().getInitialLink()
                  : Future<Uri?>.value()));
      if (uri != null && mounted) _receive(uri);
    } catch (_) {
      // No native link handler is available in widget tests or on some platforms.
    }
  }

  void _receive(Uri uri) {
    final code = CommunityInvitation.codeFromLink(uri);
    if (!mounted || code == null || !_openCodes.add(code)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        if (mounted) await widget.onInvitation(code);
      } finally {
        _openCodes.remove(code);
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

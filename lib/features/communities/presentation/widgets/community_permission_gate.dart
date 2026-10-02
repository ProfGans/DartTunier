import 'package:flutter/material.dart';
import '../../data/community_access_repository.dart';
import '../../domain/community_permissions.dart';

class CommunityPermissionGate extends StatefulWidget {
  const CommunityPermissionGate({
    super.key,
    required this.communityId,
    required this.permission,
    required this.builder,
    this.repository,
  });
  final String? communityId;
  final CommunityPermission permission;
  final WidgetBuilder builder;
  final CommunityAccessRepository? repository;
  @override
  State<CommunityPermissionGate> createState() =>
      _CommunityPermissionGateState();
}

class _CommunityPermissionGateState extends State<CommunityPermissionGate> {
  late Future<CommunityPermissions> _permissions = _load();
  Future<CommunityPermissions> _load() =>
      (widget.repository ?? CommunityAccessRepository()).permissions(
        widget.communityId!,
      );
  @override
  void didUpdateWidget(covariant CommunityPermissionGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.communityId != null &&
        (oldWidget.communityId != widget.communityId ||
            oldWidget.repository != widget.repository)) {
      _permissions = _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.communityId == null) return widget.builder(context);
    return FutureBuilder<CommunityPermissions>(
      future: _permissions,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            snapshot.hasData &&
            snapshot.data!.allows(widget.permission)) {
          return widget.builder(context);
        }
        return Scaffold(
          appBar: AppBar(title: const Text('Community-Berechtigung')),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (snapshot.connectionState != ConnectionState.done)
                      const CircularProgressIndicator()
                    else ...[
                      Text(
                        snapshot.hasError
                            ? 'Rechte konnten nicht geladen werden. Verbindung und Servereinrichtung prüfen.'
                            : 'Deiner Rolle fehlt das Recht „${widget.permission.label}“.',
                        textAlign: TextAlign.center,
                      ),
                      TextButton(
                        onPressed: () => setState(() {
                          _permissions = _load();
                        }),
                        child: const Text('Erneut prüfen'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

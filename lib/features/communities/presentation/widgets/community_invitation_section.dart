import 'package:flutter/material.dart';
import '../../data/community_access_repository.dart';
import 'community_invitation_card.dart';

class CommunityInvitationSection extends StatefulWidget {
  const CommunityInvitationSection({
    super.key,
    required this.communityId,
    required this.access,
  });
  final String communityId;
  final CommunityAccessRepository access;
  @override
  State<CommunityInvitationSection> createState() =>
      _CommunityInvitationSectionState();
}

class _CommunityInvitationSectionState
    extends State<CommunityInvitationSection> {
  late Future<String> _code = widget.access.invitation(widget.communityId);
  @override
  Widget build(BuildContext context) => FutureBuilder<String>(
    future: _code,
    builder: (context, snapshot) {
      if (snapshot.hasData) {
        return CommunityInvitationCard(inviteCode: snapshot.data!);
      }
      if (snapshot.hasError) {
        return Column(
          children: [
            const Text(
              'Einladungsrecht fehlt oder der Server ist nicht erreichbar.',
            ),
            TextButton(
              onPressed: () => setState(() {
                _code = widget.access.invitation(widget.communityId);
              }),
              child: const Text('Erneut versuchen'),
            ),
          ],
        );
      }
      return const Center(child: CircularProgressIndicator());
    },
  );
}

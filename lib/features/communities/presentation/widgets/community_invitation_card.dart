import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../domain/community_invitation.dart';

class CommunityInvitationCard extends StatelessWidget {
  const CommunityInvitationCard({super.key, required this.inviteCode});

  final String inviteCode;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Community einladen',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            if (inviteCode.isEmpty)
              const Text('Kein Einladungscode verfügbar.')
            else ...[
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 240),
                  child: Semantics(
                    label: 'QR-Code mit Einladungscode $inviteCode',
                    image: true,
                    child: QrImageView(
                      data: CommunityInvitation.link(inviteCode),
                      backgroundColor: Colors.white,
                      padding: const EdgeInsets.all(24),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SelectableText('Einladungscode: $inviteCode'),
              const SizedBox(height: 8),
              const Text(
                'QR-Code scannen und den Link öffnen. Die installierte App '
                'öffnet die Einladung. Alternativ den Code unter „Community beitreten“ eingeben.',
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () async {
                  await Clipboard.setData(
                    ClipboardData(text: CommunityInvitation.link(inviteCode)),
                  );
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Einladungslink kopiert.')),
                  );
                },
                icon: const Icon(Icons.link),
                label: const Text('Einladungslink kopieren'),
              ),
              TextButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: inviteCode));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Einladungscode kopiert.')),
                  );
                },
                icon: const Icon(Icons.copy),
                label: const Text('Code kopieren'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../../../shared/images/profile_avatar.dart';
import '../../../personal_profile/domain/personal_profile.dart';
import '../../../personal_profile/presentation/dart_setup_widgets.dart';

/// Read-only account details, loaded independently of tournament statistics.
class CommunityAccountProfile extends StatefulWidget {
  const CommunityAccountProfile({super.key, required this.load});
  final Future<PersonalProfile?> Function() load;

  @override
  State<CommunityAccountProfile> createState() => _AccountProfileState();
}

class _AccountProfileState extends State<CommunityAccountProfile> {
  late Future<PersonalProfile?> profile = widget.load();

  @override
  Widget build(BuildContext context) => FutureBuilder<PersonalProfile?>(
    future: profile,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const LinearProgressIndicator();
      }
      if (snapshot.hasError) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Das Account-Profil konnte nicht geladen werden.'),
            TextButton(
              onPressed: () => setState(() => profile = widget.load()),
              child: const Text('Profil erneut laden'),
            ),
          ],
        );
      }
      final value = snapshot.data;
      if (value == null) {
        return const Text('Noch keine Profilangaben online gespeichert.');
      }
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ProfileAvatar(radius: 40, picture: value.picture),
              const SizedBox(height: 12),
              Text(
                value.name,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              DartSetupSummary(setup: value.dartSetup),
              if (value.nationality.isNotEmpty)
                Text('Nationalität: ${value.nationality}'),
              if (value.song.isNotEmpty) Text('Walk-on-Song: ${value.song}'),
              if (value.favoritePlayer.isNotEmpty)
                Text('Lieblingsspieler: ${value.favoritePlayer}'),
              if (value.favoriteDouble.isNotEmpty)
                Text('Lieblingsdoppel: ${value.favoriteDouble}'),
            ],
          ),
        ),
      );
    },
  );
}

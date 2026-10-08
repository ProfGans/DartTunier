import '../../accounts/domain/account_user.dart';
import '../data/app_database.dart';

/// Local tournaments also accept the signed-in account without requiring a
/// second local profile. Account IDs remain stable across offline sessions.
List<PlayerProfile> tournamentPlayerChoices(
  List<PlayerProfile> profiles,
  AccountUser? account,
) {
  if (account == null || !account.isActive) return [...profiles];
  final own = profiles
      .where((p) => p.userId == account.id || p.id == account.id)
      .toList();
  return [
    if (own.isNotEmpty)
      ...own
    else
      PlayerProfile(
        id: account.id,
        userId: account.id,
        displayName: account.displayName,
        country: '',
        city: '',
        dartsSetupJson: '',
        createdAt: account.createdAt,
        isActive: true,
      ),
    ...profiles.where((p) => p.userId != account.id && p.id != account.id),
  ];
}

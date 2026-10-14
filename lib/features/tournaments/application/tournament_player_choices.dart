import '../../accounts/domain/account_user.dart';
import '../data/app_database.dart';

/// Tournament participants always come from the local player catalog.
List<PlayerProfile> tournamentPlayerChoices(
  List<PlayerProfile> profiles,
  AccountUser? _,
) => [...profiles];

import 'dart:math';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import '../domain/tournament_models.dart';

class LocalAppDatabase {
  LocalAppDatabase({Directory? baseDirectory}) : _baseDirectory = baseDirectory;

  static const schemaVersion = 2;
  static const _testUserId = '00000000-0000-4000-8000-000000000001';

  final Directory? _baseDirectory;

  Future<List<PlayerProfile>> loadPlayerProfiles() async {
    final database = await _openDatabase();
    try {
      final rows = database.select('''
        SELECT id, user_id, display_name, country, city, darts_setup_json,
               created_at, is_active
        FROM player_profiles
        WHERE is_active = 1
        ORDER BY display_name COLLATE NOCASE
      ''');
      return [for (final row in rows) PlayerProfile.fromRow(row)];
    } finally {
      database.close();
    }
  }

  Future<List<TournamentPlayer>> loadTournamentPlayers() async {
    final profiles = await loadPlayerProfiles();
    return [
      for (final profile in profiles)
        TournamentPlayer(
          profileId: profile.id,
          name: profile.displayName,
          isGenerated: false,
        ),
    ];
  }

  Future<File> databaseFile() => _databaseFile();

  Future<PlayerProfile> createPlayerProfile({
    required String displayName,
    String country = '',
    String city = '',
    String dartsSetupJson = '',
  }) async {
    final database = await _openDatabase();
    try {
      final now = DateTime.now();
      final profile = PlayerProfile(
        id: _newId(),
        userId: null,
        displayName: displayName.trim(),
        country: country.trim(),
        city: city.trim(),
        dartsSetupJson: dartsSetupJson.trim(),
        createdAt: now,
        isActive: true,
      );
      database.execute(
        '''
        INSERT INTO player_profiles (
          id, user_id, display_name, country, city, darts_setup_json,
          created_at, is_active
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ''',
        [
          profile.id,
          profile.userId,
          profile.displayName,
          profile.country,
          profile.city,
          profile.dartsSetupJson,
          profile.createdAt.toIso8601String(),
          1,
        ],
      );
      return profile;
    } finally {
      database.close();
    }
  }

  Future<void> updatePlayerProfile(PlayerProfile profile) async {
    final database = await _openDatabase();
    try {
      database.execute(
        '''
        UPDATE player_profiles
        SET display_name = ?, country = ?, city = ?, darts_setup_json = ?
        WHERE id = ?
        ''',
        [
          profile.displayName.trim(),
          profile.country.trim(),
          profile.city.trim(),
          profile.dartsSetupJson.trim(),
          profile.id,
        ],
      );
    } finally {
      database.close();
    }
  }

  Future<void> deactivatePlayerProfile(String id) async {
    final database = await _openDatabase();
    try {
      database.execute(
        'UPDATE player_profiles SET is_active = 0 WHERE id = ?',
        [id],
      );
    } finally {
      database.close();
    }
  }

  Future<Database> _openDatabase() async {
    final file = await _databaseFile();
    await file.parent.create(recursive: true);
    final database = sqlite3.open(file.path);
    database.execute('PRAGMA foreign_keys = ON');
    _migrate(database);
    _seedTestData(database);
    return database;
  }

  void _migrate(Database database) {
    final currentVersion = _currentSchemaVersion(database);
    if (currentVersion >= schemaVersion) {
      return;
    }

    database.execute('BEGIN');
    try {
      if (currentVersion < 1) {
        _createSchema(database);
      }
      if (currentVersion < 2) {
        _addPlayerActiveFlag(database);
      }
      database.execute('PRAGMA user_version = $schemaVersion');
      database.execute('COMMIT');
    } catch (_) {
      database.execute('ROLLBACK');
      rethrow;
    }
  }

  int _currentSchemaVersion(Database database) {
    final result = database.select('PRAGMA user_version');
    if (result.isEmpty || result.first.isEmpty) {
      return 0;
    }
    return result.first.values.first as int? ?? 0;
  }

  void _createSchema(Database database) {
    database.execute('''
      CREATE TABLE users (
        id TEXT PRIMARY KEY,
        username TEXT NOT NULL UNIQUE,
        display_name TEXT NOT NULL,
        email TEXT NOT NULL UNIQUE,
        avatar_url TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        last_login TEXT,
        is_active INTEGER NOT NULL DEFAULT 1
      );

      CREATE TABLE player_profiles (
        id TEXT PRIMARY KEY,
        user_id TEXT REFERENCES users(id) ON DELETE SET NULL,
        display_name TEXT NOT NULL,
        country TEXT,
        city TEXT,
        darts_setup_json TEXT,
        created_at TEXT NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1
      );

      CREATE TABLE friendships (
        id TEXT PRIMARY KEY,
        user_a TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        user_b TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        status TEXT NOT NULL,
        created_at TEXT NOT NULL,
        UNIQUE(user_a, user_b)
      );

      CREATE TABLE clubs (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT,
        created_by TEXT REFERENCES users(id) ON DELETE SET NULL,
        created_at TEXT NOT NULL
      );

      CREATE TABLE club_members (
        club_id TEXT NOT NULL REFERENCES clubs(id) ON DELETE CASCADE,
        user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        role TEXT NOT NULL,
        joined_at TEXT NOT NULL,
        PRIMARY KEY (club_id, user_id)
      );

      CREATE TABLE tournaments (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        format TEXT NOT NULL,
        created_by TEXT REFERENCES users(id) ON DELETE SET NULL,
        started_at TEXT,
        finished_at TEXT
      );

      CREATE TABLE tournament_players (
        tournament_id TEXT NOT NULL REFERENCES tournaments(id) ON DELETE CASCADE,
        user_id TEXT REFERENCES users(id) ON DELETE SET NULL,
        player_profile_id TEXT REFERENCES player_profiles(id) ON DELETE SET NULL,
        seed INTEGER,
        display_name_snapshot TEXT NOT NULL,
        PRIMARY KEY (tournament_id, player_profile_id)
      );

      CREATE TABLE leagues (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        season TEXT,
        created_at TEXT NOT NULL
      );

      CREATE TABLE league_clubs (
        league_id TEXT NOT NULL REFERENCES leagues(id) ON DELETE CASCADE,
        club_id TEXT NOT NULL REFERENCES clubs(id) ON DELETE CASCADE,
        PRIMARY KEY (league_id, club_id)
      );

      CREATE TABLE league_matches (
        id TEXT PRIMARY KEY,
        league_id TEXT NOT NULL REFERENCES leagues(id) ON DELETE CASCADE,
        club_home_id TEXT REFERENCES clubs(id) ON DELETE SET NULL,
        club_away_id TEXT REFERENCES clubs(id) ON DELETE SET NULL,
        match_date TEXT,
        status TEXT NOT NULL
      );

      CREATE TABLE matches (
        id TEXT PRIMARY KEY,
        game_type TEXT NOT NULL,
        match_mode TEXT NOT NULL,
        started_at TEXT,
        finished_at TEXT,
        winner_user_id TEXT REFERENCES users(id) ON DELETE SET NULL,
        winner_player_profile_id TEXT REFERENCES player_profiles(id) ON DELETE SET NULL,
        source_type TEXT NOT NULL,
        tournament_id TEXT REFERENCES tournaments(id) ON DELETE CASCADE,
        league_id TEXT REFERENCES leagues(id) ON DELETE CASCADE,
        club_id TEXT REFERENCES clubs(id) ON DELETE SET NULL
      );

      CREATE TABLE match_players (
        id TEXT PRIMARY KEY,
        match_id TEXT NOT NULL REFERENCES matches(id) ON DELETE CASCADE,
        user_id TEXT REFERENCES users(id) ON DELETE SET NULL,
        player_profile_id TEXT REFERENCES player_profiles(id) ON DELETE SET NULL,
        player_order INTEGER NOT NULL,
        legs_won INTEGER NOT NULL DEFAULT 0,
        avg REAL,
        first9_avg REAL,
        checkout_pct REAL,
        darts_thrown INTEGER NOT NULL DEFAULT 0
      );

      CREATE TABLE tournament_matches (
        id TEXT PRIMARY KEY,
        tournament_id TEXT NOT NULL REFERENCES tournaments(id) ON DELETE CASCADE,
        match_id TEXT NOT NULL REFERENCES matches(id) ON DELETE CASCADE,
        round_number INTEGER NOT NULL,
        bracket_position INTEGER NOT NULL
      );

      CREATE TABLE legs (
        id TEXT PRIMARY KEY,
        match_id TEXT NOT NULL REFERENCES matches(id) ON DELETE CASCADE,
        leg_number INTEGER NOT NULL,
        winner_user_id TEXT REFERENCES users(id) ON DELETE SET NULL,
        winner_player_profile_id TEXT REFERENCES player_profiles(id) ON DELETE SET NULL,
        started_at TEXT,
        finished_at TEXT
      );

      CREATE TABLE visits (
        id TEXT PRIMARY KEY,
        leg_id TEXT NOT NULL REFERENCES legs(id) ON DELETE CASCADE,
        user_id TEXT REFERENCES users(id) ON DELETE SET NULL,
        player_profile_id TEXT REFERENCES player_profiles(id) ON DELETE SET NULL,
        visit_number INTEGER NOT NULL,
        darts_used INTEGER NOT NULL,
        score INTEGER NOT NULL,
        remaining_score INTEGER NOT NULL,
        created_at TEXT NOT NULL
      );

      CREATE TABLE throws (
        id TEXT PRIMARY KEY,
        visit_id TEXT NOT NULL REFERENCES visits(id) ON DELETE CASCADE,
        dart_number INTEGER NOT NULL,
        segment TEXT NOT NULL,
        multiplier INTEGER NOT NULL,
        value INTEGER NOT NULL
      );

      CREATE TABLE checkouts (
        id TEXT PRIMARY KEY,
        leg_id TEXT NOT NULL REFERENCES legs(id) ON DELETE CASCADE,
        user_id TEXT REFERENCES users(id) ON DELETE SET NULL,
        player_profile_id TEXT REFERENCES player_profiles(id) ON DELETE SET NULL,
        checkout_score INTEGER NOT NULL,
        finishing_double TEXT,
        darts_used INTEGER NOT NULL,
        created_at TEXT NOT NULL
      );

      CREATE TABLE elo_groups (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        group_type TEXT NOT NULL
      );

      CREATE TABLE elo_ratings (
        id TEXT PRIMARY KEY,
        group_id TEXT NOT NULL REFERENCES elo_groups(id) ON DELETE CASCADE,
        user_id TEXT REFERENCES users(id) ON DELETE CASCADE,
        player_profile_id TEXT REFERENCES player_profiles(id) ON DELETE CASCADE,
        rating INTEGER NOT NULL,
        wins INTEGER NOT NULL DEFAULT 0,
        losses INTEGER NOT NULL DEFAULT 0,
        matches_played INTEGER NOT NULL DEFAULT 0,
        updated_at TEXT NOT NULL
      );

      CREATE TABLE player_statistics_cache (
        player_profile_id TEXT PRIMARY KEY REFERENCES player_profiles(id) ON DELETE CASCADE,
        user_id TEXT REFERENCES users(id) ON DELETE CASCADE,
        avg REAL,
        first9_avg REAL,
        checkout_pct REAL,
        high_finish INTEGER,
        score_60_plus INTEGER NOT NULL DEFAULT 0,
        score_100_plus INTEGER NOT NULL DEFAULT 0,
        score_140_plus INTEGER NOT NULL DEFAULT 0,
        updated_at TEXT NOT NULL
      );

      CREATE TABLE direct_messages (
        id TEXT PRIMARY KEY,
        sender_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        receiver_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        content TEXT NOT NULL,
        created_at TEXT NOT NULL
      );

      CREATE INDEX idx_player_profiles_display_name
        ON player_profiles(display_name);
      CREATE INDEX idx_tournament_players_tournament
        ON tournament_players(tournament_id, seed);
      CREATE INDEX idx_matches_tournament
        ON matches(tournament_id);
      CREATE INDEX idx_visits_player
        ON visits(player_profile_id);
    ''');
  }

  void _addPlayerActiveFlag(Database database) {
    final columns = database.select('PRAGMA table_info(player_profiles)');
    final hasActiveColumn = columns.any((row) => row['name'] == 'is_active');
    if (!hasActiveColumn) {
      database.execute(
        'ALTER TABLE player_profiles '
        'ADD COLUMN is_active INTEGER NOT NULL DEFAULT 1',
      );
    }
  }

  void _seedTestData(Database database) {
    final existingProfiles = database.select(
      'SELECT COUNT(*) AS count FROM player_profiles',
    );
    final count = existingProfiles.first['count'] as int? ?? 0;
    if (count > 0) {
      return;
    }

    final now = DateTime.now().toIso8601String();
    database.execute(
      '''
      INSERT OR IGNORE INTO users (
        id, username, display_name, email, avatar_url,
        created_at, updated_at, last_login, is_active
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      [
        _testUserId,
        'test_user',
        'Test User',
        'test@example.local',
        null,
        now,
        now,
        now,
        1,
      ],
    );

    for (final profile in _seedProfiles(now)) {
      database.execute(
        '''
        INSERT OR IGNORE INTO player_profiles (
          id, user_id, display_name, country, city, darts_setup_json,
          created_at, is_active
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ''',
        [
          profile.id,
          profile.userId,
          profile.displayName,
          profile.country,
          profile.city,
          '{"weight_g":23,"brand":"Testsetup"}',
          profile.createdAt.toIso8601String(),
          1,
        ],
      );
    }
  }

  List<PlayerProfile> _seedProfiles(String now) {
    final createdAt = DateTime.parse(now);
    return [
      PlayerProfile(
        id: '00000000-0000-4000-8000-000000000101',
        userId: _testUserId,
        displayName: 'Luke Littler',
        country: 'England',
        city: 'Warrington',
        dartsSetupJson: '{"weight_g":23,"brand":"Testsetup"}',
        createdAt: createdAt,
        isActive: true,
      ),
      PlayerProfile(
        id: '00000000-0000-4000-8000-000000000102',
        userId: _testUserId,
        displayName: 'Michael van Gerwen',
        country: 'Niederlande',
        city: 'Vlijmen',
        dartsSetupJson: '{"weight_g":23,"brand":"Testsetup"}',
        createdAt: createdAt,
        isActive: true,
      ),
      PlayerProfile(
        id: '00000000-0000-4000-8000-000000000103',
        userId: _testUserId,
        displayName: 'Gerwyn Price',
        country: 'Wales',
        city: 'Markham',
        dartsSetupJson: '{"weight_g":23,"brand":"Testsetup"}',
        createdAt: createdAt,
        isActive: true,
      ),
      PlayerProfile(
        id: '00000000-0000-4000-8000-000000000104',
        userId: _testUserId,
        displayName: 'Fallon Sherrock',
        country: 'England',
        city: 'Milton Keynes',
        dartsSetupJson: '{"weight_g":23,"brand":"Testsetup"}',
        createdAt: createdAt,
        isActive: true,
      ),
    ];
  }

  Future<File> _databaseFile() async {
    final directory = _baseDirectory ?? await _defaultBaseDirectory();
    return File(path.join(directory.path, 'app_database.sqlite'));
  }

  Future<Directory> _defaultBaseDirectory() async {
    if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
      return _applicationSupportDirectory();
    }

    final appData = Platform.environment['APPDATA'];
    final basePath = appData == null || appData.isEmpty
        ? Directory.current.path
        : appData;
    return Directory(path.join(basePath, 'DartTournamentManager'));
  }

  Future<Directory> _applicationSupportDirectory() async {
    try {
      return await getApplicationSupportDirectory();
    } catch (_) {
      return Directory.systemTemp.createTemp(
        'dart_tournament_manager_database_test_',
      );
    }
  }

  String _newId() {
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final randomPart = Random().nextInt(1 << 32).toRadixString(16);
    return '$timestamp-$randomPart';
  }
}

class PlayerProfile {
  const PlayerProfile({
    required this.id,
    required this.userId,
    required this.displayName,
    required this.country,
    required this.city,
    required this.dartsSetupJson,
    required this.createdAt,
    required this.isActive,
  });

  factory PlayerProfile.fromRow(Row row) {
    return PlayerProfile(
      id: row['id'] as String? ?? '',
      userId: row['user_id'] as String?,
      displayName: row['display_name'] as String? ?? '',
      country: row['country'] as String? ?? '',
      city: row['city'] as String? ?? '',
      dartsSetupJson: row['darts_setup_json'] as String? ?? '',
      createdAt: DateTime.tryParse(row['created_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      isActive: (row['is_active'] as int? ?? 1) == 1,
    );
  }

  final String id;
  final String? userId;
  final String displayName;
  final String country;
  final String city;
  final String dartsSetupJson;
  final DateTime createdAt;
  final bool isActive;

  PlayerProfile copyWith({
    String? displayName,
    String? country,
    String? city,
    String? dartsSetupJson,
  }) {
    return PlayerProfile(
      id: id,
      userId: userId,
      displayName: displayName ?? this.displayName,
      country: country ?? this.country,
      city: city ?? this.city,
      dartsSetupJson: dartsSetupJson ?? this.dartsSetupJson,
      createdAt: createdAt,
      isActive: isActive,
    );
  }
}

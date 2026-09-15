import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/lock_record.dart';

class LockDatabase {
  static final LockDatabase instance = LockDatabase._init();
  static Database? _database;

  LockDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('app_locks.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE locks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        packageName TEXT NOT NULL,
        appName TEXT NOT NULL,
        lockedAt INTEGER NOT NULL,
        unlockAt INTEGER NOT NULL,
        enabled INTEGER NOT NULL,
        createdAt INTEGER NOT NULL,
        iconBase64 TEXT,
        lockType TEXT NOT NULL DEFAULT 'temporary',
        sourceId TEXT DEFAULT '',
        startMinutes INTEGER DEFAULT -1,
        endMinutes INTEGER DEFAULT -1,
        daysOfWeek TEXT DEFAULT '',
        UNIQUE(packageName, lockType, sourceId)
      )
    ''');

    await db.execute('''
      CREATE TABLE focus_modes (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        icon TEXT NOT NULL,
        packageNames TEXT NOT NULL,
        durationMinutes INTEGER DEFAULT 60,
        startMinutes INTEGER DEFAULT -1,
        endMinutes INTEGER DEFAULT -1,
        daysOfWeek TEXT DEFAULT '',
        isActive INTEGER DEFAULT 0,
        unlockAt INTEGER DEFAULT 0
      )
    ''');
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add columns safely
      try {
        await db.execute("ALTER TABLE locks ADD COLUMN lockType TEXT NOT NULL DEFAULT 'temporary'");
        await db.execute("ALTER TABLE locks ADD COLUMN sourceId TEXT DEFAULT ''");
        await db.execute("ALTER TABLE locks ADD COLUMN startMinutes INTEGER DEFAULT -1");
        await db.execute("ALTER TABLE locks ADD COLUMN endMinutes INTEGER DEFAULT -1");
        await db.execute("ALTER TABLE locks ADD COLUMN daysOfWeek TEXT DEFAULT ''");
      } catch (_) {}

      await db.execute('''
        CREATE TABLE IF NOT EXISTS focus_modes (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          icon TEXT NOT NULL,
          packageNames TEXT NOT NULL,
          durationMinutes INTEGER DEFAULT 60,
          startMinutes INTEGER DEFAULT -1,
          endMinutes INTEGER DEFAULT -1,
          daysOfWeek TEXT DEFAULT '',
          isActive INTEGER DEFAULT 0,
          unlockAt INTEGER DEFAULT 0
        )
      ''');
    }
  }

  Future<int> insertOrUpdateLock(LockRecord lock) async {
    final db = await instance.database;
    return await db.insert(
      'locks',
      lock.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<LockRecord>> getAllLocks() async {
    final db = await instance.database;
    final result = await db.query('locks', orderBy: 'unlockAt ASC');
    return result.map((json) => LockRecord.fromMap(json)).toList();
  }

  Future<List<LockRecord>> getActiveLocks() async {
    final all = await getAllLocks();
    return all.where((lock) => lock.isCurrentlyLocked).toList();
  }

  Future<List<LockRecord>> getSchedules() async {
    final db = await instance.database;
    final result = await db.query('locks', where: "lockType = 'schedule'");
    return result.map((json) => LockRecord.fromMap(json)).toList();
  }

  Future<LockRecord?> getLockByPackage(String packageName, {String? lockType, String? sourceId}) async {
    final db = await instance.database;
    var whereClause = 'packageName = ?';
    final whereArgs = <dynamic>[packageName];

    if (lockType != null) {
      whereClause += ' AND lockType = ?';
      whereArgs.add(lockType);
    }
    if (sourceId != null) {
      whereClause += ' AND sourceId = ?';
      whereArgs.add(sourceId);
    }

    final result = await db.query(
      'locks',
      where: whereClause,
      whereArgs: whereArgs,
      limit: 1,
    );
    if (result.isNotEmpty) {
      return LockRecord.fromMap(result.first);
    }
    return null;
  }

  Future<int> deleteLock(String packageName, {String? lockType, String? sourceId}) async {
    final db = await instance.database;
    var whereClause = 'packageName = ?';
    final whereArgs = <dynamic>[packageName];

    if (lockType != null) {
      whereClause += ' AND lockType = ?';
      whereArgs.add(lockType);
    }
    if (sourceId != null) {
      whereClause += ' AND sourceId = ?';
      whereArgs.add(sourceId);
    }

    return await db.delete(
      'locks',
      where: whereClause,
      whereArgs: whereArgs,
    );
  }

  Future<int> cleanupExpiredLocks() async {
    final db = await instance.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    return await db.delete(
      'locks',
      where: "lockType = 'temporary' AND unlockAt <= ?",
      whereArgs: [now],
    );
  }

  // Focus Modes Database Operations
  Future<int> saveFocusMode(Map<String, dynamic> focusMode) async {
    final db = await instance.database;
    return await db.insert(
      'focus_modes',
      focusMode,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getFocusModes() async {
    final db = await instance.database;
    return await db.query('focus_modes', orderBy: 'name ASC');
  }

  Future<int> deleteFocusMode(String id) async {
    final db = await instance.database;
    return await db.delete('focus_modes', where: 'id = ?', whereArgs: [id]);
  }
}

import 'package:ruya/database/database_migrator.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class AppDatabase {
  static final AppDatabase instance = AppDatabase._init();
  static Database? _database;

  /// Current schema version. v1-v11 are Menstrudel, v12+ are RUYA.
  static const int schemaVersion = 12;

  AppDatabase._init();

  Future<Database> get database async {
    return _database ??= await init();
  }

  Future<Database> init({bool inMemory = false}) async {
    if (_database != null && !inMemory) {
      return _database!;
    }

    String path;
    if (inMemory) {
      path = inMemoryDatabasePath;
    } else {
      final dbPath = await getDatabasesPath();
      path = join(dbPath, 'app_database.db');
    }

    _database = await openDatabase(
      path,
      version: schemaVersion,
      onCreate: _createDB,
      onUpgrade: DatabaseMigrator.upgrade,
    );
    return _database!;
  }

  Future _createDB(Database db, int version) async {
    await DatabaseMigrator.createPeriodTables(db);

    await DatabaseMigrator.createLogTables(db);

    await DatabaseMigrator.createPillTables(db);

    await DatabaseMigrator.createLarcTables(db);

    await DatabaseMigrator.createSanitaryProductTables(db);

    await DatabaseMigrator.createSexualActivityTables(db);

    await DatabaseMigrator.createUserTables(db);

    // RUYA additions are applied exactly like the upgrade path so a fresh
    // install and a migrated database always end up with the same schema.
    await DatabaseMigrator.applyDailyLogV12(db);
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}
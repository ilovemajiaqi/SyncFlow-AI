import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase._(this.database);

  static const String eventsTable = 'events';

  final Database database;

  static Future<AppDatabase> open() async {
    final databasesPath = await getDatabasesPath();
    final path = p.join(databasesPath, 'syncflow_ai.db');

    final database = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $eventsTable (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id TEXT NOT NULL,
            title TEXT NOT NULL,
            start_time TEXT NOT NULL,
            duration_minutes INTEGER NOT NULL,
            target_keyword TEXT,
            status INTEGER NOT NULL DEFAULT 1,
            created_at TEXT NOT NULL,
            location TEXT
          )
        ''');

        await db.execute(
          'CREATE INDEX idx_events_start_time ON $eventsTable(start_time)',
        );
      },
    );

    return AppDatabase._(database);
  }
}

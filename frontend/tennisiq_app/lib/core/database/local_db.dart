import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class LocalDbHelper {
  static final LocalDbHelper instance = LocalDbHelper._init();
  static Database? _database;

  LocalDbHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('tennisiq_offline.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    
    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE imu_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        timestamp TEXT,
        uploaded INTEGER,
        payload TEXT
      )
    ''');
  }

  Future<int> insertIMUSession(List<Map<String, dynamic>> imuChunks) async {
    final db = await instance.database;
    final jsonStr = jsonEncode(imuChunks);
    
    return await db.insert('imu_sessions', {
      'timestamp': DateTime.now().toIso8601String(),
      'uploaded': 0,
      'payload': jsonStr,
    });
  }

  Future<List<Map<String, dynamic>>> getUnsyncedSessions() async {
    final db = await instance.database;
    return await db.query('imu_sessions', where: 'uploaded = ?', whereArgs: [0]);
  }

  Future<void> markAsSynced(int id) async {
    final db = await instance.database;
    await db.update('imu_sessions', {'uploaded': 1}, where: 'id = ?', whereArgs: [id]);
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}

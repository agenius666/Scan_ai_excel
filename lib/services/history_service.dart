import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/history_record.dart';
import 'storage_service.dart';

class HistoryService {
  HistoryService({StorageService? storageService})
      : _storageService = storageService ?? StorageService();

  final StorageService _storageService;
  Database? _db;

  Future<Database> _database() async {
    if (_db != null) return _db!;
    final dir = await _storageService.getPrivateAppDirectory();
    final path = p.join(dir.path, 'scanexcel.db');
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE history (
            id TEXT PRIMARY KEY,
            taskName TEXT NOT NULL,
            pdfPath TEXT NOT NULL,
            excelPath TEXT NOT NULL,
            createdAt TEXT NOT NULL,
            status TEXT NOT NULL,
            summary TEXT NOT NULL
          )
        ''');
      },
    );
    return _db!;
  }

  Future<List<HistoryRecord>> load() async {
    final db = await _database();
    final rows = await db.query('history', orderBy: 'createdAt DESC');
    return rows.map((e) => HistoryRecord.fromJson(e)).toList(growable: false);
  }

  Future<void> append(HistoryRecord record) async {
    final db = await _database();
    await db.insert(
      'history',
      record.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}

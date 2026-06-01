import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/translation_item.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('translations.db');
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
      CREATE TABLE translations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        text TEXT NOT NULL,
        date TEXT NOT NULL,
        time TEXT NOT NULL,
        timestamp INTEGER NOT NULL
      )
    ''');
  }

  // Çeviri ekle
  Future<int> addTranslation(TranslationItem item) async {
    final db = await database;
    return await db.insert('translations', item.toMap());
  }

  // Tüm çevirileri getir (en yeni en üstte)
  Future<List<TranslationItem>> getAllTranslations() async {
    final db = await database;
    final result = await db.query(
      'translations',
      orderBy: 'timestamp DESC',
    );

    return result.map((map) => TranslationItem.fromMap(map)).toList();
  }

  // Çeviri sil
  Future<int> deleteTranslation(int id) async {
    final db = await database;
    return await db.delete(
      'translations',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Tüm çevirileri sil
  Future<int> deleteAllTranslations() async {
    final db = await database;
    return await db.delete('translations');
  }

  // Veritabanını kapat
  Future close() async {
    final db = await database;
    db.close();
  }
}
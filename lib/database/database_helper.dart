import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'vetstan.db');
    
    // Delete existing database only in debug mode to start fresh during development
    if (kDebugMode) {
      await deleteDatabase(path);
    }
    
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Create sync table to track last sync times
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        last_synced_at INTEGER NOT NULL,
        last_version INTEGER
      )
    ''');

    // Create dictionary tables
    await db.execute('''
      CREATE TABLE IF NOT EXISTS dictionary (
        id TEXT PRIMARY KEY,
        name TEXT,
        kurdish TEXT,
        arabic TEXT,
        description TEXT,
        image_url TEXT,
        last_updated INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS diseases (
        id TEXT PRIMARY KEY,
        name TEXT,
        cause TEXT,
        control TEXT,
        kurdish TEXT,
        symptoms TEXT,
        category TEXT,
        image_url TEXT,
        last_updated INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS drugs (
        id TEXT PRIMARY KEY,
        name TEXT,
        description TEXT,
        other_info TEXT,
        side_effect TEXT,
        usage TEXT,
        drug_class TEXT,
        kurdish TEXT,
        category TEXT,
        image_url TEXT,
        last_updated INTEGER
      )
    ''');

    // Create books table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS books (
        id TEXT PRIMARY KEY,
        title TEXT,
        author TEXT,
        description TEXT,
        category TEXT,
        image_url TEXT,
        last_updated INTEGER
      )
    ''');

    // Create categories table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name_en TEXT NOT NULL,
        name_ku TEXT NOT NULL,
        type TEXT NOT NULL
      )
    ''');

    // Create items table with foreign key
    await db.execute('''
      CREATE TABLE IF NOT EXISTS items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category_id INTEGER,
        name_en TEXT NOT NULL,
        name_ku TEXT NOT NULL,
        image_path TEXT,
        description_en TEXT,
        description_ku TEXT,
        content TEXT,
        FOREIGN KEY (category_id) REFERENCES categories (id)
      )
    ''');

    // Insert initial categories
    await _insertInitialCategories(db);

    // Initialize sync table with default values
    await db.insert('sync', {
      'type': 'dictionary',
      'last_synced_at': 0,
      'last_version': 0
    });
    await db.insert('sync', {
      'type': 'diseases',
      'last_synced_at': 0,
      'last_version': 0
    });
    await db.insert('sync', {
      'type': 'drugs',
      'last_synced_at': 0,
      'last_version': 0
    });
  }

  Future<void> _insertInitialCategories(Database db) async {
    // Check if categories already exist
    final List<Map<String, dynamic>> categories = await db.query('categories');
    if (categories.isEmpty) {
      await db.insert('categories', {
        'name_en': 'Instruments',
        'name_ku': 'ئامێرەکان',
        'type': 'instruments'
      });

      await db.insert('categories', {
        'name_en': 'Slides',
        'name_ku': 'سلایدەکان',
        'type': 'slides'
      });
    }
  }

  // Sync-related methods
  Future<int> getLastSyncTime(String type) async {
    final db = await database;
    final result = await db.query(
      'sync',
      where: 'type = ?',
      whereArgs: [type],
      limit: 1
    );
    return result.isNotEmpty ? result.first['last_synced_at'] as int : 0;
  }

  Future<void> updateLastSyncTime(String type, int timestamp) async {
    final db = await database;
    await db.update(
      'sync',
      {'last_synced_at': timestamp},
      where: 'type = ?',
      whereArgs: [type]
    );
  }

  Future<int> getLastVersion(String type) async {
    final db = await database;
    final result = await db.query(
      'sync',
      where: 'type = ?',
      whereArgs: [type],
      limit: 1
    );
    return result.isNotEmpty ? result.first['last_version'] as int : 0;
  }

  Future<void> updateLastVersion(String type, int version) async {
    final db = await database;
    await db.update(
      'sync',
      {'last_version': version},
      where: 'type = ?',
      whereArgs: [type]
    );
  }

  // Dictionary-specific methods
  Future<List<Map<String, dynamic>>> getAllDictionary() async {
    final db = await database;
    return await db.query('dictionary');
  }

  Future<void> insertOrUpdateDictionary(Map<String, dynamic> data) async {
    final db = await database;
    final existing = await db.query(
      'dictionary',
      where: 'term = ?',
      whereArgs: [data['term']],
      limit: 1
    );
    if (existing.isNotEmpty) {
      await db.update(
        'dictionary',
        data,
        where: 'term = ?',
        whereArgs: [data['term']]
      );
    } else {
      await db.insert('dictionary', data);
    }
  }

  Future<void> clearDictionary() async {
    final db = await database;
    await db.delete('dictionary');
  }

  // Generic methods for any table
  Future<int> insert(String table, Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert(table, data);
  }

  Future<List<Map<String, dynamic>>> getAll(String table) async {
    final db = await database;
    return await db.query(table);
  }

  Future<Map<String, dynamic>?> getById(String table, int id) async {
    final db = await database;
    final results = await db.query(
      table,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<List<Map<String, dynamic>>> getAllItemsByCategory(int categoryId) async {
    final db = await database;
    return await db.query(
      'items',
      where: 'category_id = ?',
      whereArgs: [categoryId],
    );
  }

  Future<List<Map<String, dynamic>>> getAllItemsByType(String type) async {
    final db = await database;
    final results = await db.rawQuery('''
      SELECT i.* 
      FROM items i 
      INNER JOIN categories c ON i.category_id = c.id 
      WHERE c.type = ?
    ''', [type]);
    return results;
  }

  Future<int> update(String table, Map<String, dynamic> data, int id) async {
    final db = await database;
    return await db.update(
      table,
      data,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> delete(String table, int id) async {
    final db = await database;
    return await db.delete(
      table,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Specific methods for instruments
  Future<int> insertInstrument(String nameEn, String nameKu, String imagePath, String descriptionEn, String descriptionKu) async {
    final db = await database;
    
    // Get the instruments category
    final List<Map<String, dynamic>> categories = await db.query(
      'categories',
      where: 'type = ?',
      whereArgs: ['instruments'],
      limit: 1,
    );
    
    if (categories.isEmpty) {
      throw Exception('Instruments category not found');
    }
    
    final categoryId = categories.first['id'] as int;
    
    return await db.insert('items', {
      'category_id': categoryId,
      'name_en': nameEn,
      'name_ku': nameKu,
      'image_path': imagePath,
      'description_en': descriptionEn,
      'description_ku': descriptionKu,
    });
  }

  Future<List<Map<String, dynamic>>> getAllInstruments() async {
    return getAllItemsByType('instruments');
  }

  // Specific methods for slides
  Future<void> insertSlide(String nameEn, String nameKu, String imagePath, String content) async {
    final db = await database;
    
    // Get the slides category
    final List<Map<String, dynamic>> categories = await db.query(
      'categories',
      where: 'type = ?',
      whereArgs: ['slides'],
      limit: 1,
    );
    
    if (categories.isEmpty) {
      throw Exception('Slides category not found');
    }
    
    final categoryId = categories.first['id'] as int;
    
    await db.insert('items', {
      'category_id': categoryId,
      'name_en': nameEn,
      'name_ku': nameKu,
      'image_path': imagePath,
      'content': content,
    });
  }

  Future<List<Map<String, dynamic>>> getAllSlides() async {
    return getAllItemsByType('slides');
  }
}

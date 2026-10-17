import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class OfflineStore {
  static Database? _db;
  static Future<Database> open() async {
    if (_db != null) return _db!;
    final dir = await getApplicationSupportDirectory();
    _db = await openDatabase('${dir.path}/wasel_local.db', version: 2,
      onUpgrade: (db, oldVersion, newVersion) async {
        await db.execute('CREATE TABLE IF NOT EXISTS conversations (id INTEGER PRIMARY KEY, kind TEXT, title TEXT)');
        await db.execute('CREATE TABLE IF NOT EXISTS cached_media (id INTEGER PRIMARY KEY AUTOINCREMENT, message_id INTEGER, conversation_id INTEGER, local_path TEXT, mime_type TEXT, saved_at TEXT)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_local_messages_time ON messages(conversation_id, created_at)');
      },
      onCreate: (db, version) async {
        await db.execute('CREATE TABLE messages (id INTEGER, conversation_id INTEGER, sender_id INTEGER, kind TEXT, content TEXT, created_at TEXT, cloud_purged INTEGER DEFAULT 0, PRIMARY KEY(conversation_id,id))');
        await db.execute('CREATE INDEX idx_local_messages_time ON messages(conversation_id, created_at)');
        await db.execute('CREATE TABLE conversations (id INTEGER PRIMARY KEY, kind TEXT, title TEXT)');
        await db.execute('CREATE TABLE cached_media (id INTEGER PRIMARY KEY AUTOINCREMENT, message_id INTEGER, conversation_id INTEGER, local_path TEXT, mime_type TEXT, saved_at TEXT)');
      });
    return _db!;
  }

  static Future<void> saveMessages(int conversationId, List<Map<String, dynamic>> items) async {
    final db = await open();
    for (final item in items) {
      final id = (item['id'] as num?)?.toInt();
      if (id == null) continue;
      final existing = await db.query('messages', columns: ['content'], where: 'conversation_id = ? AND id = ?', whereArgs: [conversationId, id], limit: 1);
      final incomingContent = item['content'] as String?;
      final previousContent = existing.isEmpty ? null : existing.first['content'] as String?;
      await db.insert('messages', {
        'id': id,
        'conversation_id': conversationId,
        'sender_id': (item['sender_id'] as num?)?.toInt() ?? 0,
        'kind': item['kind'] as String? ?? 'text',
        'content': incomingContent ?? previousContent,
        'created_at': item['created_at']?.toString() ?? DateTime.now().toUtc().toIso8601String(),
        'cloud_purged': item['cloud_purged'] == true ? 1 : 0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  static Future<List<Map<String, dynamic>>> messages(int conversationId) async {
    final db = await open();
    return db.query('messages', where: 'conversation_id = ?', whereArgs: [conversationId], orderBy: 'id ASC');
  }

  static Future<void> saveConversations(List<Map<String, dynamic>> items) async {
    final db = await open();
    final batch = db.batch();
    for (final item in items) {
      final id = (item['id'] as num?)?.toInt();
      if (id == null) continue;
      batch.insert('conversations', {'id': id, 'kind': item['kind'] ?? 'private', 'title': item['title']},
        conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  static Future<List<Map<String, dynamic>>> conversations() async {
    final db = await open();
    return db.query('conversations', orderBy: 'id DESC');
  }

  static Future<String> saveMediaBytes({
    required int conversationId,
    required int messageId,
    required List<int> bytes,
    required String fileName,
    String? mimeType,
  }) async {
    final root = await getApplicationSupportDirectory();
    final directory = Directory('${root.path}/wasel_media/$conversationId');
    await directory.create(recursive: true);
    final safeName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final file = File('${directory.path}/${messageId}_$safeName');
    await file.writeAsBytes(bytes, flush: true);
    final db = await open();
    await db.insert('cached_media', {
      'message_id': messageId,
      'conversation_id': conversationId,
      'local_path': file.path,
      'mime_type': mimeType,
      'saved_at': DateTime.now().toUtc().toIso8601String(),
    });
    return file.path;
  }

  static Future<List<Map<String, dynamic>>> cachedMedia(int conversationId) async {
    final db = await open();
    return db.query('cached_media', where: 'conversation_id = ?', whereArgs: [conversationId]);
  }
}

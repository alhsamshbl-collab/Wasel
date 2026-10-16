import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';

class OfflineStore {
  static Database? _db;
  static Future<Database> open() async {
    if (_db != null) return _db!;
    final dir = await getApplicationSupportDirectory();
    _db = await openDatabase('${dir.path}/wasel_local.db', version: 1,
      onCreate: (db, version) async {
        await db.execute('CREATE TABLE messages (id INTEGER, conversation_id INTEGER, sender_id INTEGER, kind TEXT, content TEXT, created_at TEXT, cloud_purged INTEGER DEFAULT 0, PRIMARY KEY(conversation_id,id))');
        await db.execute('CREATE TABLE cached_media (id INTEGER PRIMARY KEY, message_id INTEGER, conversation_id INTEGER, local_path TEXT, mime_type TEXT)');
      });
    return _db!;
  }
  static Future<void> saveMessages(int conversationId, List<Map<String, dynamic>> items) async {
    final db = await open();
    final batch = db.batch();
    for (final item in items) {
      batch.insert('messages', {
        'id': item['id'], 'conversation_id': conversationId, 'sender_id': item['sender_id'],
        'kind': item['kind'] ?? 'text', 'content': item['content'], 'created_at': item['created_at']?.toString() ?? '',
        'cloud_purged': item['cloud_purged'] == true ? 1 : 0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }
  static Future<List<Map<String, dynamic>>> messages(int conversationId) async {
    final db = await open();
    return db.query('messages', where: 'conversation_id = ?', whereArgs: [conversationId], orderBy: 'id ASC');
  }
}

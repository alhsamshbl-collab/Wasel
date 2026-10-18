import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import '../data/offline_store.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}
class _AuthScreenState extends State<AuthScreen> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController();
  final username = TextEditingController();
  final password = TextEditingController();
  final inviteCode = TextEditingController();
  final storage = const FlutterSecureStorage();
  bool register = false, busy = false, checkingSession = true;
  String? error;
  static const base = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:8000');
  @override
  void initState() {
    super.initState();
    restoreSession();
  }
  Future<void> restoreSession() async {
    try {
      final token = await storage.read(key: 'wasel_access_token').timeout(const Duration(seconds: 4));
      final userJson = await storage.read(key: 'wasel_user').timeout(const Duration(seconds: 4));
      if (token != null && userJson != null) {
        final user = jsonDecode(userJson) as Map<String, dynamic>;
        if (!mounted) return;
        Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
          builder: (_) => HomeScreen(user: user, token: token),
        ));
        return;
      }
    } catch (_) {}
    if (mounted) setState(() => checkingSession = false);
  }
  @override
  void dispose() { name.dispose(); username.dispose(); password.dispose(); inviteCode.dispose(); super.dispose(); }
  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    setState(() { busy = true; error = null; });
    try {
      final response = await http.post(Uri.parse('$base/api/auth/${register ? 'register' : 'login'}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username.text.trim(), 'password': password.text,
          if (register) 'display_name': name.text.trim(), if (register) 'invite_code': inviteCode.text.trim()}));
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode < 200 || response.statusCode >= 300) throw Exception(body['detail'] ?? 'تعذر تنفيذ الطلب');
      final user = body['user'] as Map<String, dynamic>;
      final token = body['access_token'] as String;
      await storage.write(key: 'wasel_access_token', value: token);
      await storage.write(key: 'wasel_user', value: jsonEncode(user));
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
        builder: (_) => HomeScreen(user: user, token: token),
      ));
    } catch (e) {
      if (mounted) setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    } finally { if (mounted) setState(() => busy = false); }
  }
  @override
  Widget build(BuildContext context) {
    if (checkingSession) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fieldFill = isDark ? const Color(0xFF172326) : Colors.white;
    final fieldText = isDark ? Colors.white : const Color(0xFF172326);
    final fieldLabel = isDark ? const Color(0xFFD2DEE0) : const Color(0xFF526368);

    InputDecoration decoration(String label) => InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: fieldLabel),
      filled: true,
      fillColor: fieldFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: isDark ? const Color(0xFF344448) : const Color(0xFFD7E1E3)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: isDark ? const Color(0xFF344448) : const Color(0xFFD7E1E3)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF25B8C2), width: 1.8),
      ),
    );

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight - 56),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Form(
                    key: form,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Icon(Icons.forum_rounded, size: 58, color: Color(0xFF25B8C2)),
                        const SizedBox(height: 14),
                        Text(
                          register ? 'إنشاء حساب في واصل' : 'مرحبًا بعودتك',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        Text('تواصل بلا حدود', textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge),
                        const SizedBox(height: 28),
                        if (register) ...[
                          TextFormField(
                            controller: name,
                            style: TextStyle(color: fieldText),
                            decoration: decoration('الاسم الظاهر'),
                            textInputAction: TextInputAction.next,
                            validator: (v) => v == null || v.trim().isEmpty ? 'أدخل الاسم الظاهر' : null,
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: inviteCode,
                            style: TextStyle(color: fieldText),
                            obscureText: true,
                            decoration: decoration('رمز الدعوة الخاص'),
                            textInputAction: TextInputAction.next,
                            validator: (v) => v == null || v.trim().length < 8 ? 'أدخل رمز الدعوة' : null,
                          ),
                          const SizedBox(height: 14),
                        ],
                        TextFormField(
                          controller: username,
                          style: TextStyle(color: fieldText),
                          decoration: decoration('اسم المستخدم'),
                          textInputAction: TextInputAction.next,
                          autocorrect: false,
                          validator: (v) => v == null || v.trim().length < 3 ? 'أدخل اسم مستخدم صحيحًا' : null,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: password,
                          style: TextStyle(color: fieldText),
                          obscureText: true,
                          decoration: decoration('كلمة المرور (8 أحرف على الأقل)'),
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => busy ? null : submit(),
                          validator: (v) => v == null || v.length < 8 ? 'كلمة المرور قصيرة' : null,
                        ),
                        if (error != null) Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          height: 52,
                          child: FilledButton(
                            onPressed: busy ? null : submit,
                            child: busy
                              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                              : Text(register ? 'إنشاء الحساب' : 'تسجيل الدخول'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: busy ? null : () => setState(() { register = !register; error = null; }),
                          child: Text(register ? 'لديك حساب؟ تسجيل الدخول' : 'ليس لديك حساب؟ أنشئ حسابًا'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.user, required this.token});
  final Map<String, dynamic> user;
  final String token;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}
class _HomeScreenState extends State<HomeScreen> {
  static const base = _AuthScreenState.base;
  List<Map<String, dynamic>> conversations = [];
  List<Map<String, dynamic>> users = [];
  bool loading = true;
  String? error;
  Map<String, String> userNames = {};
  Map<String, String> headers() => {'Authorization': 'Bearer ${widget.token}', 'Content-Type': 'application/json'};
  @override
  void initState() { super.initState(); load(); }
  Future<void> load() async {
    setState(() { loading = true; error = null; });
    try {
      final results = await Future.wait([
        http.get(Uri.parse('$base/api/conversations'), headers: headers()).timeout(const Duration(seconds: 8)),
        http.get(Uri.parse('$base/api/users'), headers: headers()).timeout(const Duration(seconds: 8)),
        http.get(Uri.parse('$base/api/global-group'), headers: headers()).timeout(const Duration(seconds: 8)),
      ]);
      if (results.any((r) => r.statusCode < 200 || r.statusCode >= 300)) throw Exception('تعذر تحميل بيانات الحساب');
      conversations = (jsonDecode(results[0].body) as List).cast<Map<String, dynamic>>();
      users = (jsonDecode(results[1].body) as List).cast<Map<String, dynamic>>();
      final globalGroup = jsonDecode(results[2].body) as Map<String, dynamic>;
      if (!conversations.any((c) => c['id'] == globalGroup['id'])) conversations.insert(0, globalGroup);
      await OfflineStore.saveConversations(conversations);
      userNames = {for (final u in users) '${u['id']}': u['display_name'] as String};
    } catch (_) {
      conversations = await OfflineStore.conversations();
      users = [];
      error = conversations.isEmpty ? 'لا توجد محادثات محفوظة على هذا الجهاز بعد' : null;
    }
    if (mounted) setState(() { loading = false; });
  }
  Future<void> startConversation(Map<String, dynamic> other) async {
    try {
      final r = await http.post(Uri.parse('$base/api/conversations'), headers: headers(), body: jsonEncode({'user_ids': [other['id']]}));
      if (r.statusCode < 200 || r.statusCode >= 300) throw Exception((jsonDecode(r.body) as Map)['detail'] ?? 'تعذر بدء المحادثة');
      final data = jsonDecode(r.body) as Map<String, dynamic>;
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ChatScreen(
        conversationId: data['id'] as int, token: widget.token, userId: widget.user['id'] as int,
        title: other['display_name'] as String)));
      await load();
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')))); }
  }
  Future<void> openConversation(Map<String, dynamic> c) async {
    final title = c['title'] as String? ?? 'محادثة ${c['id']}';
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ChatScreen(
      conversationId: c['id'] as int, token: widget.token, userId: widget.user['id'] as int, title: title)));
    if (mounted) load();
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('واصل | Wasel'), actions: [IconButton(onPressed: load, icon: const Icon(Icons.refresh))]),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () {
        showModalBottomSheet<void>(
          context: context,
          showDragHandle: true,
          builder: (sheetContext) => SafeArea(
            child: SizedBox(
              height: 360,
              child: users.isEmpty
                  ? const Center(child: Text('لا يوجد مستخدمون آخرون بعد'))
                  : ListView(children: [
                      const ListTile(title: Text('ابدأ محادثة جديدة')),
                      ...users.map((u) => ListTile(
                        leading: CircleAvatar(child: Text((u['display_name'] as String).substring(0, 1))),
                        title: Text(u['display_name'] as String),
                        subtitle: Text('@${u['username']}'),
                        onTap: () {
                          Navigator.pop(sheetContext);
                          startConversation(u);
                        },
                      )),
                    ]),
            ),
          ),
        );
      },
      icon: const Icon(Icons.add_comment_outlined),
      label: const Text('محادثة جديدة'),
    ),
    body: loading ? const Center(child: CircularProgressIndicator()) : error != null
      ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text(error!), TextButton(onPressed: load, child: const Text('إعادة المحاولة'))]))
      : RefreshIndicator(onRefresh: load, child: ListView(padding: const EdgeInsets.all(12), children: [
          ListTile(leading: CircleAvatar(child: Text((widget.user['display_name'] as String).substring(0, 1))),
            title: Text('أهلًا بك، ${widget.user['display_name']}'), subtitle: const Text('تواصل بلا حدود')),
          const Divider(),
          if (conversations.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Text('لا توجد محادثات بعد. اضغط «محادثة جديدة» للبدء.', textAlign: TextAlign.center)),
          ...conversations.map((c) => Card(child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.forum_outlined)),
            title: Text(c['title'] as String? ?? 'محادثة ${c['id']}'),
            subtitle: Text(c['kind'] == 'group' ? 'مجموعة' : 'محادثة خاصة'),
            trailing: const Icon(Icons.chevron_left), onTap: () => openConversation(c)))),
        ])),
  );
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.conversationId, required this.token, required this.userId, required this.title});
  final int conversationId;
  final String token;
  final int userId;
  final String title;
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}
class _ChatScreenState extends State<ChatScreen> {
  static const base = _AuthScreenState.base;
  final input = TextEditingController();
  final scroll = ScrollController();
  final picker = ImagePicker();
  final recorder = AudioRecorder();
  final audioPlayer = AudioPlayer();
  bool recording = false, sendingMedia = false;
  final messages = <Map<String, dynamic>>[];
  WebSocketChannel? channel;
  StreamSubscription<dynamic>? subscription;
  bool loading = true, connected = false;
  String? error;
  @override
  void initState() { super.initState(); loadHistory(); connect(); }
  Future<void> loadHistory() async {
    try {
      final r = await http.get(Uri.parse('$base/api/conversations/${widget.conversationId}/messages'),
        headers: {'Authorization': 'Bearer ${widget.token}'}).timeout(const Duration(seconds: 8));
      if (r.statusCode < 200 || r.statusCode >= 300) throw Exception('تعذر تحميل الرسائل');
      final rows = (jsonDecode(r.body) as List).cast<Map<String, dynamic>>();
      await OfflineStore.saveMessages(widget.conversationId, rows);
      for (final item in rows) {
        final id = (item['id'] as num?)?.toInt();
        if (id == null) continue;
        try {
          await http.post(Uri.parse('$base/api/conversations/${widget.conversationId}/messages/$id/ack'),
            headers: {'Authorization': 'Bearer ${widget.token}'}).timeout(const Duration(seconds: 4));
        } catch (_) {}
      }
      final localRows = await OfflineStore.messages(widget.conversationId);
      if (mounted) setState(() { messages.addAll(localRows); loading = false; });
      scrollToEnd();
    } catch (e) {
      final localRows = await OfflineStore.messages(widget.conversationId);
      if (mounted) {
        setState(() {
          messages.addAll(localRows);
        error = localRows.isEmpty ? 'لا يوجد سجل محفوظ على هذا الجهاز بعد' : 'وضع عدم الاتصال: تعرض الرسائل المحفوظة محليًا';
          loading = false;
        });
      }
      scrollToEnd();
    }
  }
  void connect() {
    final root = Uri.parse(base);
    final uri = root.replace(scheme: root.scheme == 'https' ? 'wss' : 'ws',
      path: '/ws/conversations/${widget.conversationId}', queryParameters: {'token': widget.token});
    try {
      channel = WebSocketChannel.connect(uri);
      subscription = channel!.stream.listen((event) {
        final data = jsonDecode(event as String) as Map<String, dynamic>;
        if (data['type'] == 'message' && mounted) {
          OfflineStore.saveMessages(widget.conversationId, [data]);
          final messageId = (data['id'] as num?)?.toInt();
          if (messageId != null) {
            http.post(Uri.parse('$base/api/conversations/${widget.conversationId}/messages/$messageId/ack'),
              headers: {'Authorization': 'Bearer ${widget.token}'}).catchError((_) => http.Response('', 500));
          }
          setState(() {
            if (!messages.any((m) => m['id'] == data['id'])) messages.add(data);
          });
          scrollToEnd();
        }
      }, onError: (_) { if (mounted) setState(() => connected = false); },
        onDone: () { if (mounted) setState(() => connected = false); });
      channel!.ready.then((_) { if (mounted) setState(() => connected = true); })
        .catchError((Object _) { if (mounted) setState(() => connected = false); });
    } catch (_) { connected = false; }
  }
  void scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scroll.hasClients) {
        scroll.animateTo(scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 180), curve: Curves.easeOut);
      }
    });
  }
  void send() {
    final text = input.text.trim();
    if (text.isEmpty || channel == null || !connected) return;
    channel!.sink.add(jsonEncode({'content': text}));
    input.clear();
  }

  Future<void> chooseMedia(String type) async {
    if (sendingMedia) return;
    try {
      XFile? selected;
      if (type == 'image') selected = await picker.pickImage(source: ImageSource.gallery, imageQuality: 88);
      if (type == 'video') selected = await picker.pickVideo(source: ImageSource.gallery);
      if (type == 'file') {
        final result = await FilePicker.platform.pickFiles(withData: false);
        final path = result?.files.single.path;
        if (path != null) await uploadMedia(File(path), result!.files.single.name);
        return;
      }
      if (selected != null) await uploadMedia(File(selected.path), selected.name);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر اختيار الملف: $e')));
    }
  }

  Future<void> toggleRecording() async {
    try {
      if (recording) {
        final path = await recorder.stop();
        if (mounted) setState(() => recording = false);
        if (path != null) await uploadMedia(File(path), 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a', forcedMime: 'audio/mp4');
      } else {
        if (!await recorder.hasPermission()) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى السماح باستخدام الميكروفون')));
          return;
        }
        final dir = await getTemporaryDirectory();
        final path = '${dir.path}/wasel_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
        await recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
        if (mounted) setState(() => recording = true);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر تسجيل الصوت: $e')));
    }
  }

  Future<void> uploadMedia(File file, String name, {String? forcedMime}) async {
    if (sendingMedia) return;
    setState(() => sendingMedia = true);
    try {
      final request = http.MultipartRequest('POST', Uri.parse('$base/api/conversations/${widget.conversationId}/media'));
      request.headers['Authorization'] = 'Bearer ${widget.token}';
      request.files.add(await http.MultipartFile.fromPath('file', file.path, filename: name,
        contentType: forcedMime == null ? null : http.MediaType.parse(forcedMime)));
      final streamed = await request.send().timeout(const Duration(minutes: 2));
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final detail = jsonDecode(response.body);
        throw Exception(detail is Map ? detail['detail'] ?? 'فشل الإرسال' : 'فشل الإرسال');
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (mounted && !messages.any((m) => m['id'] == data['id'])) {
        setState(() => messages.add(data));
        await OfflineStore.saveMessages(widget.conversationId, [data]);
        scrollToEnd();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => sendingMedia = false);
    }
  }

  Future<void> openAttachment(Map<String, dynamic> message) async {
    try {
      final content = jsonDecode(message['content'] as String) as Map<String, dynamic>;
      final response = await http.get(Uri.parse('$base${content['download_path']}'),
        headers: {'Authorization': 'Bearer ${widget.token}'}).timeout(const Duration(minutes: 2));
      if (response.statusCode != 200) throw Exception('تعذر تنزيل المرفق');
      final localPath = await OfflineStore.saveMediaBytes(conversationId: widget.conversationId,
        messageId: (message['id'] as num).toInt(), bytes: response.bodyBytes,
        fileName: content['name'] as String? ?? 'attachment.bin', mimeType: content['content_type'] as String?);
      final mime = (content['content_type'] as String? ?? '');
      if (mime.startsWith('audio/')) {
        await audioPlayer.setFilePath(localPath);
        await audioPlayer.play();
      } else if (mime.startsWith('image/')) {
        if (mounted) showDialog<void>(context: context, builder: (ctx) => Dialog(child: InteractiveViewer(child: Image.file(File(localPath)))));
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم تنزيل الملف إلى: $localPath')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    }
  }

  Widget messageBody(Map<String, dynamic> m) {
    final kind = m['kind'] as String? ?? 'text';
    final content = m['content'] as String? ?? '';
    if (kind == 'text') return Text(content);
    try {
      final meta = jsonDecode(content) as Map<String, dynamic>;
      final mime = meta['content_type'] as String? ?? '';
      final name = meta['name'] as String? ?? 'مرفق';
      if (mime.startsWith('image/')) {
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.image_outlined, size: 32), Text(name),
          TextButton.icon(onPressed: () => openAttachment(m), icon: const Icon(Icons.open_in_new), label: const Text('عرض الصورة')),
        ]);
      }
      final icon = mime.startsWith('video/') ? Icons.video_file_outlined :
        mime.startsWith('audio/') ? Icons.audio_file_outlined : Icons.attach_file;
      return Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon), const SizedBox(width: 8), Flexible(child: Text(name)),
        IconButton(onPressed: () => openAttachment(m), icon: Icon(mime.startsWith('audio/') ? Icons.play_arrow : Icons.download)),
      ]);
    } catch (_) { return Text(content.isEmpty ? 'مرفق' : content); }
  }
  @override
  void dispose() { subscription?.cancel(); channel?.sink.close(); input.dispose(); scroll.dispose(); recorder.dispose(); audioPlayer.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.title), actions: [Padding(padding: const EdgeInsets.all(16), child: Icon(
      Icons.circle, size: 10, color: connected ? Colors.green : Colors.orange))]),
    body: Column(children: [
      if (error != null) Padding(padding: const EdgeInsets.all(8), child: Text(error!)),
      if (!connected) const LinearProgressIndicator(minHeight: 2),
      Expanded(child: loading ? const Center(child: CircularProgressIndicator()) : ListView.builder(
        controller: scroll, padding: const EdgeInsets.all(12), itemCount: messages.length,
        itemBuilder: (context, index) {
          final m = messages[index];
          final mine = m['sender_id'] == widget.userId;
          return Align(alignment: mine ? Alignment.centerLeft : Alignment.centerRight,
            child: Container(margin: const EdgeInsets.symmetric(vertical: 4), padding: const EdgeInsets.all(12),
              constraints: const BoxConstraints(maxWidth: 300),
              decoration: BoxDecoration(color: mine ? Theme.of(context).colorScheme.primaryContainer : Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16)),
              child: messageBody(m)));
        })),
      if (sendingMedia) const LinearProgressIndicator(minHeight: 2),
      SafeArea(child: Padding(padding: const EdgeInsets.all(8), child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          IconButton(onPressed: sendingMedia ? null : () => chooseMedia('image'), tooltip: 'إرسال صورة', icon: const Icon(Icons.image_outlined)),
          IconButton(onPressed: sendingMedia ? null : () => chooseMedia('video'), tooltip: 'إرسال فيديو', icon: const Icon(Icons.video_library_outlined)),
          IconButton(onPressed: sendingMedia ? null : () => chooseMedia('file'), tooltip: 'إرسال مرفق', icon: const Icon(Icons.attach_file)),
          IconButton(onPressed: sendingMedia ? null : toggleRecording, tooltip: recording ? 'إيقاف وإرسال التسجيل' : 'تسجيل صوت', color: recording ? Colors.red : null,
            icon: Icon(recording ? Icons.stop_circle_outlined : Icons.mic_none)),
          Expanded(child: TextField(controller: input, minLines: 1, maxLines: 4,
            decoration: const InputDecoration(hintText: 'اكتب رسالة...', border: OutlineInputBorder()))),
          const SizedBox(width: 4), IconButton.filled(onPressed: connected ? send : null, icon: const Icon(Icons.send)),
        ]),
        if (recording) const Align(alignment: Alignment.centerRight, child: Text('جارٍ تسجيل الرسالة الصوتية…')),
      ]))),
    ]),
  );
}

import 'dart:async';
import 'dart:convert';
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
      final token = await storage.read(key: 'wasel_access_token');
      final userJson = await storage.read(key: 'wasel_user');
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
    if (checkingSession) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
    body: SafeArea(child: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(24),
      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420), child: Form(key: form,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Icon(Icons.forum_rounded, size: 60, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 16),
          Text(register ? 'إنشاء حساب في واصل' : 'مرحبًا بعودتك', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8), const Text('تواصل بلا حدود', textAlign: TextAlign.center), const SizedBox(height: 24),
          if (register) ...[
            TextFormField(controller: name, decoration: const InputDecoration(labelText: 'الاسم الظاهر', border: OutlineInputBorder()),
              validator: (v) => v == null || v.trim().isEmpty ? 'أدخل الاسم الظاهر' : null),
            const SizedBox(height: 12),
            TextFormField(controller: inviteCode, obscureText: true, decoration: const InputDecoration(labelText: 'رمز الدعوة الخاص', border: OutlineInputBorder()),
              validator: (v) => v == null || v.trim().length < 8 ? 'أدخل رمز الدعوة' : null),
            const SizedBox(height: 12),
          ],
          TextFormField(controller: username, decoration: const InputDecoration(labelText: 'اسم المستخدم', border: OutlineInputBorder()),
            validator: (v) => v == null || v.trim().length < 3 ? 'أدخل اسم مستخدم صحيحًا' : null),
          const SizedBox(height: 12),
          TextFormField(controller: password, obscureText: true, decoration: const InputDecoration(labelText: 'كلمة المرور (8 أحرف على الأقل)', border: OutlineInputBorder()),
            validator: (v) => v == null || v.length < 8 ? 'كلمة المرور قصيرة' : null),
          if (error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
          const SizedBox(height: 20),
          FilledButton(onPressed: busy ? null : submit, child: Text(busy ? 'يرجى الانتظار' : register ? 'إنشاء الحساب' : 'تسجيل الدخول')),
          TextButton(onPressed: busy ? null : () => setState(() { register = !register; error = null; }),
            child: Text(register ? 'لديك حساب؟ تسجيل الدخول' : 'ليس لديك حساب؟ أنشئ حسابًا')),
        ])))))));
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
      ]);
      if (results.any((r) => r.statusCode < 200 || r.statusCode >= 300)) throw Exception('تعذر تحميل بيانات الحساب');
      conversations = (jsonDecode(results[0].body) as List).cast<Map<String, dynamic>>();
      users = (jsonDecode(results[1].body) as List).cast<Map<String, dynamic>>();
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
  @override
  void dispose() { subscription?.cancel(); channel?.sink.close(); input.dispose(); scroll.dispose(); super.dispose(); }
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
              child: Text(m['content'] as String? ?? '')));
        })),
      SafeArea(child: Padding(padding: const EdgeInsets.all(8), child: Row(children: [
        Expanded(child: TextField(controller: input, minLines: 1, maxLines: 4,
          decoration: const InputDecoration(hintText: 'اكتب رسالة...', border: OutlineInputBorder()))),
        const SizedBox(width: 8), IconButton.filled(onPressed: connected ? send : null, icon: const Icon(Icons.send)),
      ]))),
    ]),
  );
}

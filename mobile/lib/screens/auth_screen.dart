import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

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
  bool register = false, busy = false;
  String? error;
  static const base = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:8000');
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
      await storage.write(key: 'wasel_access_token', value: body['access_token'] as String);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: (_) => HomeScreen(
        user: body['user'] as Map<String, dynamic>, token: body['access_token'] as String)));
    } catch (e) {
      if (mounted) setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    } finally { if (mounted) setState(() => busy = false); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
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
        ]))))));
}
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.user, required this.token});
  final Map<String, dynamic> user;
  final String token;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('واصل | Wasel')),
    body: ListView(padding: const EdgeInsets.all(20), children: [
      CircleAvatar(radius: 36, child: Text((user['display_name'] as String).substring(0, 1))),
      const SizedBox(height: 16),
      Text('أهلًا بك، ${user['display_name']}', style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
      const SizedBox(height: 12), const Text('تواصل بلا حدود', textAlign: TextAlign.center), const SizedBox(height: 24),
      const Card(child: ListTile(leading: Icon(Icons.people_outline), title: Text('المستخدمون'), subtitle: Text('واجهة المستخدمين قيد الاستكمال'))),
      const Card(child: ListTile(leading: Icon(Icons.forum_outlined), title: Text('المحادثات'), subtitle: Text('واجهة المحادثات قيد الاستكمال'))),
    ]),
  );
}

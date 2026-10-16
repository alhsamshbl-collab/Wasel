# واصل | Wasel
**تواصل بلا حدود** — مشروع مراسلة عربي/إنجليزي، مستهدف لمجموعة خاصة من ستة أشخاص.

## التقنية
- تطبيق الهاتف: Flutter/Dart، واجهة RTL عربية، تسجيل/دخول مع حفظ رمز الجلسة بأمان، قائمة المستخدمين والمحادثات، محادثة نصية لحظية.
- الخادم: FastAPI/Python، SQLAlchemy 2 async، PostgreSQL، Alembic، JWT.
- REST: التسجيل برمز دعوة مع حد أقصى ستة حسابات، الدخول، الملف الشخصي، قائمة المستخدمين، الحظر، إنشاء المحادثات وسجل الرسائل.
- WebSocket: `/ws/conversations/{conversation_id}?token=ACCESS_TOKEN` لإرسال الرسائل النصية الفورية.
- Docker Compose لتشغيل PostgreSQL والخادم، وGitHub Actions لاختبار الخادم وبناء APK.

## تشغيل محلي
1. انسخ `.env.example` إلى `.env`، وغيّر `POSTGRES_PASSWORD` و`JWT_SECRET` و`REGISTRATION_CODE` إلى قيم خاصة قوية.
2. شغّل `docker compose up --build -d`.
3. أنشئ الجداول عبر `docker compose exec api alembic upgrade head`.
4. افحص `http://127.0.0.1:8000/health` ووثائق API عبر `http://127.0.0.1:8000/docs`.
5. اختبر الخادم: `cd server && pip install -r requirements.txt && pytest -q`.
6. تطبيق الهاتف: `cd mobile && flutter pub get && flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000` على محاكي Android.

## البناء التلقائي
تابع البناء من:
https://github.com/alhsamshbl-collab/Wasel/actions
عند نجاح مهمة Android، نزّل `wasel-android-apk` من Artifacts في صفحة التشغيل.

## حدود النسخة الحالية — مهم
هذه نسخة تطويرية وليست تطبيقًا إنتاجيًا مكتملًا بعد. المحادثات النصية اللحظية تعمل عبر WebSocket على نسخة خادم واحدة؛ لا توجد حتى الآن خدمة رفع/تنزيل خاصة للصور والفيديو والصوت، ولا تسجيل/إرسال مقاطع صوتية، إشعارات، استعادة كلمة المرور، أو إدارة جلسات كاملة. يلزم اختبار تكامل فعلي مع PostgreSQL وWebSocket ومراجعة أمنية قبل النشر. لا تشغّل عدة نسخ من الخادم دون وسيط بث مشترك. رمز الدعوة الافتراضي في الإعدادات للتطوير فقط ويجب تغييره قبل النشر.

## النشر
راجع `docs/SETUP_AR.md` و`docs/PYTHONANYWHERE_AR.md`. لا ترفع الأسرار إلى GitHub، ولا تفتح PostgreSQL للعامة. في الإنتاج استخدم HTTPS/WSS وتخزين ملفات خاصًا ونسخًا احتياطية مجرّبة.

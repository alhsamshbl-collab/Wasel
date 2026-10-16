# واصل | Wasel
**تواصل بلا حدود** — مشروع مراسلة عربي/إنجليزي، مستهدف لمجموعة خاصة من ستة أشخاص.

## التقنية
- تطبيق الهاتف: Flutter / Dart مع واجهة RTL عربية، شاشة تسجيل/دخول وتخزين آمن لرمز الجلسة.
- الخادم: FastAPI / Python، SQLAlchemy 2 async، PostgreSQL، Alembic، JWT.
- REST: تسجيل حساب/دخول، الملف الشخصي، قائمة المستخدمين، الحظر، المحادثات وسجل الرسائل.
- WebSocket: `/ws/conversations/{conversation_id}?token=ACCESS_TOKEN` لإرسال الرسائل النصية الفورية.
- Docker Compose لتشغيل PostgreSQL والخادم، وGitHub Actions لاختبار الخادم وبناء APK.

## تشغيل محلي
1. انسخ `.env.example` إلى `.env` وغيّر `POSTGRES_PASSWORD` و`JWT_SECRET` إلى قيم قوية.
2. شغّل `docker compose up --build -d`.
3. أنشئ الجداول عبر `docker compose exec api alembic upgrade head`.
4. افحص `http://127.0.0.1:8000/health` ووثائق API عبر `http://127.0.0.1:8000/docs`.
5. اختبر الخادم: `cd server && pip install -r requirements.txt && pytest -q`.
6. تطبيق الهاتف: `cd mobile && flutter pub get && flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000` على محاكي Android.

## البناء التلقائي
شاهد عمليات البناء من تبويب Actions:
https://github.com/alhsamshbl-collab/Wasel/actions
عند نجاح مهمة Android، نزّل `wasel-android-apk` من Artifacts في صفحة التشغيل.

## حدود النسخة الحالية — مهم
هذه نسخة تطويرية وليست تطبيقًا إنتاجيًا مكتملًا بعد. واجهة Flutter لا تعرض بعد جميع شاشات المحادثات ولا تتصل بعميل WebSocket، والرسائل اللحظية النصية فقط؛ رفع الصور/الفيديو/الصوت، تنزيل المرفقات الخاصة، الإشعارات، إدارة الجلسات وإعادة تعيين كلمة المرور، واختبارات تكامل قاعدة البيانات ما زالت تحتاج تنفيذًا واختبارًا. بث WebSocket يستخدم ذاكرة عملية واحدة، لذا لا تشغّل عدة نسخ من الخادم دون وسيط بث مشترك. لا تنشر قبل استكمال هذه النقاط ومراجعة الأمان.

## النشر
راجع `docs/SETUP_AR.md` و`docs/PYTHONANYWHERE_AR.md`. لا ترفع الأسرار إلى GitHub، ولا تفتح PostgreSQL للعامة. في الإنتاج استخدم HTTPS/WSS وتخزين ملفات خاصًا ونسخًا احتياطية مجرّبة.

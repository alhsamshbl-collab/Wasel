# تشغيل واصل من الصفر

## السيرفر محليًا
1. ثبّت Docker وDocker Compose.
2. انسخ `.env.example` إلى `.env` ثم غيّر كلمات المرور والمفتاح السري.
3. شغّل `docker compose up --build -d`.
4. شغّل `docker compose exec api alembic upgrade head`.
5. افحص `curl http://127.0.0.1:8000/health` وافتح `http://127.0.0.1:8000/docs`.

## تطبيق الهاتف
ثبّت Flutter وAndroid SDK، ثم نفّذ من مجلد `mobile/`:
`flutter pub get` ثم `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000`.
على هاتف حقيقي استخدم عنوان IP الذي يمكن للهاتف الوصول إليه. استخدم HTTPS في الإنتاج.

## VPS
استخدم نطاقًا وTLS عبر Caddy أو Nginx مع تمرير WebSocket. أبقِ PostgreSQL داخل شبكة Docker ولا تفتح المنفذ 5432 للعامة. خزّن الأسرار خارج Git، واستخدم تخزين كائنات خاصًا للمرفقات، وخذ نسخًا احتياطية خارج الخادم واختبر الاستعادة.

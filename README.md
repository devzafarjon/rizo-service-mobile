# RIZO Service — mobile apps (Flutter)

Two apps that talk to the same API as the website (`rizo-service-full`). Nothing new on the server is needed: same
endpoints, same roles, same statuses, same translations (uz / ru / en).

| App | Who | Device | What it does |
| --- | --- | --- | --- |
| **RIZO Texnik** (`apps/rizo_staff`) | Technicians (tablet or phone), admin / dispatcher and front desk (phone or tablet) | Tablet + phone | Technician: four-column board (tablet) or tabs (phone), job screen with photos, services, parts, extras, outcome, estimate, part orders, QR scan, earnings, schedule, **offline mode**. Admin / front desk: dashboard, all requests with filters, request detail (assign, status, decision, estimate, payments, notes, pickup), new request with intake, alerts, technicians, part orders, customers, visit calendar |
| **RIZO Mijoz** (`apps/rizo_customer`) | Customers | Phone | Sign in / sign up / forgot password, my requests with live status, approve or decline an estimate (choose optional lines), messages to the service, "technician is on the way", payment info, pickup confirmation (tap or signature), rating, new request in three steps with photos, register a product, notifications, track a request without signing in, service centers |

`packages/rizo_core` holds everything shared: API client, session, translations, status rules, models, theme, widgets and
the offline queue.

## Offline mode (technician)

* The job list and every open job are saved on the device while online.
* Without a connection the technician can still start / pause / resume jobs, mark "on my way" and "arrived", pick
  services, parts and extras, build an estimate, order a part, record the outcome, take photos and complete the job.
  Changes show immediately and wait in a queue (an orange bar shows how many).
* When the connection returns the queue is sent **in the order it was made**; then the server's own figures replace the
  on-device estimates. A change the server refuses (for example the job was reassigned) is reported once and dropped.
* Photos taken offline are stored in the app's private folder until uploaded.
* Signing out warns if changes are still waiting.

## Running it

Flutter 3.35 or newer (the project was built with 3.47). From the repo folder:

```bash
cd apps/rizo_staff          # or apps/rizo_customer
flutter pub get
flutter run -d chrome --dart-define=API_URL=http://localhost:4000   # quick look on the web
flutter run                                                         # a connected phone / emulator
```

* Android emulator reaches your computer's API at `http://10.0.2.2:4000` (this is the debug default).
* A real phone on the same Wi-Fi: use your computer's address, e.g. `--dart-define=API_URL=http://192.168.1.20:4000`.
* Debug builds show a **Server address** link on the sign-in screen so you can switch servers without rebuilding.

### Release builds

The API address is fixed at build time:

```bash
flutter build apk --release \
  --dart-define=API_URL=https://YOUR-API.onrender.com \
  --dart-define=WEB_URL=https://YOUR-SITE.netlify.app
```

`WEB_URL` is only used to build the customer's tracking link (`/t/<token>`). Use `flutter build appbundle` for Google Play
and `flutter build ipa` for the App Store. Add `--dart-define=ALLOW_SERVER_CHANGE=true` only for internal test builds.

The API's `CLIENT_ORIGIN` may list several origins separated by commas (the website first). Native apps do not send an
origin, so they need nothing; only a web build of these apps would.

## Shared wording

The apps read the website's translation files. After you change `client/src/i18n/locales/*.json` in `rizo-service-full`:

```bash
./tool/sync_assets.sh                 # copies the locales and logo into packages/rizo_core
python3 tool/check_i18n.py            # lists keys the apps use that no language file has
```

Texts that exist only in the apps live in `packages/rizo_core/assets/mobile/{uz,ru,en}.json`.

## Checks

```bash
cd packages/rizo_core && flutter analyze && flutter test
cd ../../apps/rizo_staff && flutter analyze && flutter test
cd ../rizo_customer && flutter analyze && flutter test
```

## Still to do by hand (needs your accounts)

* **Store accounts**: Apple Developer Program (99 USD / year) and Google Play Console (25 USD once).
* **App icon and splash**: the Flutter default is used until you provide a square icon (1024 × 1024).
  `flutter_launcher_icons` can generate every size from one file.
* **Application IDs**: `uz.rizo.rizo_staff` / `uz.rizo.rizo_customer`. Change them once, before the first store upload
  (Android: `android/app/build.gradle.kts`; iOS: Xcode → Runner → Signing).
* **Signing**: an Android upload keystore and Apple signing certificates.
* **Push notifications** are not included. They need a Firebase project (`google-services.json` /
  `GoogleService-Info.plist`) and a server part that sends them. Today the apps refresh every 30–60 seconds while open,
  and customers still get SMS.
* **iOS builds** need a Mac with Xcode (accept its license once: `sudo xcodebuild -license accept`).
* **Android builds** need the Android SDK (Android Studio).

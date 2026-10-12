# RIZO Service — mobile apps (Flutter)

Two apps that talk to the same API as the website (`rizo-service-full`). Nothing new on the server is needed: same
endpoints, same roles, same statuses, same translations (uz / ru / en).

| App | Who | Device | What it does |
| --- | --- | --- | --- |
| **RIZO Texnik** (`apps/rizo_staff`) | Technicians (tablet or phone), admin / dispatcher and front desk (phone or tablet) | Tablet + phone | Technician: four-column board (tablet) or tabs (phone), job screen with photos, services, parts, extras, outcome, estimate, part orders, QR scan, earnings, schedule, **offline mode**. Admin / front desk: dashboard, all requests with filters, request detail (assign, status, decision, estimate, payments, notes, pickup), new request with intake, alerts, technicians, part orders, customers, visit calendar |
| **RIZO Mijoz** (`apps/rizo_customer`) | Customers | Phone | Sign in / sign up / forgot password, my requests with live status, approve or decline an estimate (choose optional lines), messages to the service, "technician is on the way", payment info, pickup confirmation (tap or signature), rating, new request in three steps with photos, register a product, notifications, track a request without signing in, service centers |

Both apps have a **dark mode** (Settings → Theme: light / dark / follow the device, saved on the device). The website has the
same switch next to the language menu. Colors live in `packages/rizo_core/lib/src/theme.dart`: use `Brand.surface`, `Brand.muted`,
`Brand.ink` … instead of hard-coded colors so both modes keep working (`Colors.white` is only for text on purple buttons).

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
flutter pub get                                                     # also after pulling new changes
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
* **App icon**: made from the RIZO SERVICE lockup (`tool/icon/icon.png`, 1024 × 1024, plus an Android adaptive
  foreground). To change it, replace those files and run `dart run flutter_launcher_icons` in each app.
  The splash screen (logo on white) comes from `flutter_native_splash`; regenerate it with `dart run flutter_native_splash:create`.
* **Application IDs**: `uz.rizo.rizo_staff` / `uz.rizo.rizo_customer`. Change them once, before the first store upload
  (Android: `android/app/build.gradle.kts`; iOS: Xcode → Runner → Signing).
* **Signing**: an Android upload keystore and Apple signing certificates.
* **Push notifications** work on Android (Firebase). Put `google-services.json` in `apps/<app>/android/app/` (not in git) and set
  `FIREBASE_SERVICE_ACCOUNT` on the API host. iPhone still needs an Apple Developer account. Everything is in `PUSH_NOTIFICATIONS.md`.
* **iOS builds** need a Mac with Xcode (accept its license once: `sudo xcodebuild -license accept`).
* **Android builds** need Android Studio. If Flutter cannot find Java, point it at the one bundled with Android Studio:
  `flutter config --jdk-dir "/Applications/Android Studio.app/Contents/jbr/Contents/Home"`. A debug build for the emulator:
  `flutter build apk --debug --dart-define=API_URL=http://10.0.2.2:4000`. Tested: the technician/admin app on an Android 17 emulator.
* **Store texts** (uz / ru / en) and the review checklist are in `STORE.md`. The push notification plan is in
  `PUSH_NOTIFICATIONS.md`.

## Spare-part control (RIZO Texnik)

Admin, front desk and warehouse see the same four views as the website's `/app/part-orders`: what to order (grouped by supplier, with a message to copy), jobs waiting for parts, orders (receive all or part), suppliers (admin and warehouse edit). Admin: More → Spare parts, and the tiles on the dashboard open it. Warehouse: it is the first screen. The customer app shows a banner on a request that waits for a part (ordered or not, expected date). Code: `apps/rizo_staff/lib/parts/`, models in `packages/rizo_core/lib/src/models.dart`.

## Warehouses (RIZO Texnik)

The warehouse role's first screen is **Warehouses** (admin and front desk: More → Warehouses). Pick a warehouse (a keeper tied to one warehouse sees only that one) and work through the tabs: **Requests** (technicians' and branch admins' requests to send: send all or part, promise a date, or refuse with a reason), **Incoming** (parts on the way: confirm what arrived; ask for a part), **Stock** (count a shelf, set its minimum, ask for more), **Restock** (everything below its minimum with the quickest source for each; one tap sends the requests), **History**, and for the admin **Warehouses** (add / edit / switch off, link to a service centre). More → Technician stock gives parts to technicians and takes them back (admin and warehouse).

The technician's job screen shows, for a part the shelf lacks, **where it is and what arrives soonest** (warehouses by delivery days, and the supplier); the fastest is preselected and any can be chosen (offline: the request is queued and the server picks the fastest). Requests for the job and their state (requested, sent, refused) are listed under the job's orders. "My stock" asks a warehouse to top up the van and confirms what arrives. Code: `apps/rizo_staff/lib/warehouse/`, `apps/rizo_staff/lib/tech/part_request_sheet.dart`, models (`Warehouse`, `StockTransfer`, `SourceOption`, …) in `packages/rizo_core/lib/src/models.dart`. The wording is in the shared `warehouse.*` keys (merge new website keys into `packages/rizo_core/assets/locales/*.json` with a script, not with `tool/sync_assets.sh`, while the other branch's `auto.*` keys exist).

## Telegram (both apps)

Settings → **Telegram** (`TelegramCard` in `packages/rizo_core`): "Connect Telegram" opens the bot with a one-time link, shows whether the account is connected and disconnects. Staff can also switch the alerts that go to Telegram on and off. The customer's channel choice (SMS / Telegram / both) is unchanged. What the bot does is described in the website's README ("Telegram bot").

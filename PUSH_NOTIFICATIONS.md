# Push notifications

Status: **built and working on Android** (tested on an Android 17 emulator with real Firebase messages: staff and customer apps, language,
tap opens the request). **iPhone is not switched on yet**: it needs an Apple Developer account (see the end).

## How it works

* Every notification the user sees in the bell is also sent as a push to every phone they are signed in on
  (`server/src/lib/push.ts`, called from `notifyStaff.ts` and `notifyCustomer.ts`). Staff receive **all** their notifications; customers
  receive their status messages. A technician also gets a push when a job is assigned to them (push only, no bell entry).
* The text is written in the language of the phone (uz / ru / en), from the same wording as the website (`server/src/lib/pushTexts.generated.ts`,
  regenerate with `node server/scripts/sync-push-texts.mjs` after changing `client/src/i18n/locales/*.json`).
* Tapping a notification opens the request in the app (admin and front desk: request detail; technician: the job; customer: the request).
* After sign-in (or when the app starts signed in) the app asks for notification permission, gets a Firebase token and registers it
  (`POST /api/staff/devices`, `/api/customer/devices`). On sign-out it removes the token (`POST …/devices/remove`). Tokens Firebase reports as
  gone are deleted by the server. Table: `device_tokens`.
* Without Firebase configured the server only logs `[push:console] …` and the apps still work.

## Setup (done for Android)

1. Firebase project `rizo-service`, Android apps `uz.rizo.rizo_staff` and `uz.rizo.rizo_customer`.
2. `google-services.json` copied to `apps/<app>/android/app/` (kept out of git; it contains both apps, so the same file works for both).
   Keep a copy at `~/Desktop/RIZO/firebase/`.
3. Server: put the service-account JSON in the environment as **`FIREBASE_SERVICE_ACCOUNT`** (Render → Environment → the JSON text).
   For local work use `FIREBASE_SERVICE_ACCOUNT_FILE=/path/to/service-account.json`. **Never commit this file.**
4. Deploy: the migration `20261008100000_device_tokens` runs automatically (`start:prod`).

Try it: sign in on a phone, then `npm run push-test -w server -- <phone> [staff|customer]`.

## iPhone (to do, needs an Apple Developer account, 99 USD / year)

1. Apple Developer → Keys → create an **APNs Auth Key (.p8)** (note the Key ID and Team ID).
2. Firebase → Project settings → Cloud Messaging → Apple app configuration → upload the `.p8` with Key ID and Team ID.
3. Firebase → add iOS apps with the bundle ids **`uz.rizo.rizoStaff`** and **`uz.rizo.rizoCustomer`** (note the capital letters), download
   `GoogleService-Info.plist` for each and add it to `apps/<app>/ios/Runner/` (Xcode → Runner → add files; kept out of git).
4. Xcode → Runner → Signing & Capabilities → add **Push Notifications** and **Background Modes → Remote notifications**.
5. Build on a real device (push does not work on the simulator).

## Decisions
* Staff receive push for **all** notifications. Quiet hours were not requested ("tungi rejim" means dark mode).
* If the application ids change, register the new ids in Firebase and replace `google-services.json`.

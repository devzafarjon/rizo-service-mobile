# Push notifications — plan (not built yet)

Status: **not implemented.** The apps refresh by themselves while open (every 30–60 seconds) and customers still receive SMS.
Push needs a Firebase project and credentials that only you can create, so this file describes what to do and what the code
change will be, so it can be built in one go once the credentials exist.

## What you do (about 30 minutes)

1. Create a Firebase project at console.firebase.google.com (free, "Spark" plan is enough).
2. Add the apps: Android `uz.rizo.rizo_staff` and `uz.rizo.rizo_customer`, iOS with the same bundle ids (change the ids first if you
   decided on different ones — see README).
3. Download `google-services.json` (Android) and `GoogleService-Info.plist` (iOS) for each app and put them in
   `apps/<app>/android/app/` and `apps/<app>/ios/Runner/`.
4. iOS only: in the Apple Developer account create an **APNs Auth Key (.p8)** and upload it in Firebase → Project settings →
   Cloud Messaging.
5. Firebase → Project settings → Service accounts → **Generate new private key** (JSON). Put its content in the API's environment
   as `FIREBASE_SERVICE_ACCOUNT` (Render → Environment). Never commit this file.

## What gets built

**Server (`rizo-service-full/server`)**
* New table `device_tokens` (id, user scope `staff|customer`, user id, token, platform, locale, last_seen_at); migration.
* `POST /api/staff/devices` and `POST /api/customer/devices` to register / refresh a token, `DELETE` on sign-out.
* `lib/push.ts` using `firebase-admin` to send; wired next to the existing SMS/Telegram sending in `notifyCustomer.ts` and
  `notifyStaff.ts` so every existing notification code (estimate sent, technician on the way, part arrived, new job assigned,
  customer message, overdue …) also becomes a push, text taken from the same translations (the user's language).
* Invalid tokens are removed when Firebase reports them.

**Apps**
* `firebase_core` + `firebase_messaging` in `rizo_core`; ask for permission after sign-in, register the token, refresh it, remove it
  on sign-out.
* Tapping a notification opens the request (`serviceRequestId` is sent in the payload).
* Android 13+ notification permission; iOS "Push Notifications" and "Background Modes → Remote notifications" capabilities.

## Decisions to confirm before building
* Should staff get push for everything the bell shows, or only for assignments and customer replies?
* Quiet hours for customers (no push at night)?

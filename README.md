# 📱 ShoutOut — Flutter Mobile App

ShoutOut lets people create events and collect short, heartfelt video messages
from friends, family, and communities.

Private. Joyful. Phone-native.

---

## Tech Stack
- Flutter (iOS + Android)
- Firebase: Auth, Firestore, Storage, FCM
- go_router, image_picker, video_player, sign_in_with_apple

---

## Auth
- Email / Google / Apple
- Required to upload
- Guests can view limited event pages

---

## App Navigation
Bottom tabs:
1) Home
2) Events
3) Uploads
4) Profile

---

## Events
Create events with:
- Name
- Type (Birthday, Wedding, Memorial, Church, Other w/ custom label)
- Date
- Cover image (overlay + title text)
- Optional description

Defaults:
- Privacy: Signed-in users only
- Status: Open

Roles:
- Host
- Co-host(s)
- Member

---

## Sharing & Joining (Share-Code First)
Primary join method:
- Human-readable share code + link

Example:
shoutout/EliseWedding-April-6-2026

Behavior:
- App installed → opens event
- App not installed → lightweight landing page
- No forced download
- Sign-in required to upload

QR codes are optional (Phase 1.5+).

---

## Video Uploads
- 90s max
- Portrait preferred; landscape allowed
- Up to 5 per user per event
- Instant local preview; async upload

Visibility:
- Host/co-host: all videos
- Uploader: own video only

---

## Notifications
- New upload (host/co-host)
- Event closing soon (host)
- Event closed (host/co-host)

---

## Premium
Visible in Settings only:
- “Premium — Coming Soon”
  (No payments in MVP)

---

## Non-Goals
- Payments
- Celebrity booking
- Google Drive
- Social features
- Full web app

---

## Local Setup
flutter pub get
flutter run

Ensure Firebase is configured for iOS & Android.



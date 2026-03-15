# RoyalNest Planner

RoyalNest Planner is a Flutter floor-planning app with an optional Node.js API
for authentication and cloud layout storage.

## Stack

- Flutter + Dart
- Express + SQLite
- Local file storage fallback for sessions and layouts

## Run the app

```bash
flutter pub get
flutter run
```

Without a backend, the planner still opens and local save/load continues to
work.

## Run the backend

```bash
cd backend
npm install
npm run start
```

The API listens on `http://localhost:8000` and creates
`backend/data/planner.db` automatically.

## Backend mail setup

Forgot-password OTP mail supports two modes:

- `MAIL_MODE=log`
  Local/dev mode. OTP prints in backend logs.
- `MAIL_MODE=smtp`
  Sends OTP to the user's inbox using SMTP credentials.

Create `backend/.env` from `backend/.env.example` and set your mail values.

## API configuration

The app resolves backend URLs in this order:

1. `API_BASE_URL`
2. Platform defaults (`10.0.2.2` on Android emulator, `localhost` elsewhere)
3. Optional `API_LAN_BASE_URL`

Examples:

```bash
flutter run --dart-define=API_BASE_URL=http://localhost:8000/api
flutter run --dart-define=API_LAN_BASE_URL=http://192.168.1.20:8000/api
```

## Main endpoints

- `GET /health`
- `POST /api/auth/register`
- `POST /api/auth/login`
- `POST /api/auth/forgot-password/send-otp`
- `POST /api/auth/forgot-password/verify-otp`
- `POST /api/auth/forgot-password/reset`
- `GET /api/auth/me`
- `POST /api/auth/logout`
- `GET /api/layouts`
- `GET /api/layouts/:id`
- `POST /api/layouts`
- `PUT /api/layouts/:id`
- `DELETE /api/layouts/:id`

## Deploy the backend

```bash
vercel deploy backend -y
```

After deployment, point the Flutter app at your stable project URL:

```bash
flutter run --dart-define=API_BASE_URL=https://your-project.vercel.app/api
```

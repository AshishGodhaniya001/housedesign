# test_app

[![Flutter](https://img.shields.io/badge/Flutter-3.38-blue?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.10-0175C2?logo=dart)](https://dart.dev)
[![Backend](https://img.shields.io/badge/Backend-Express%20%2B%20SQLite-2ea44f)](#run-backend-api-sqlite)
[![Deploy](https://img.shields.io/badge/Deploy-Vercel-black?logo=vercel)](#deploy-backend-to-vercel)

Flutter floor planner app with a local Node.js backend for database persistence.

## Run Flutter App

```bash
flutter pub get
flutter run
```

## Run Backend API (SQLite)

```bash
cd backend
npm install
npm run start
```

Backend runs on `http://localhost:8000` and creates `backend/data/planner.db` automatically.

## API Endpoints

- `GET /health`
- `POST /api/auth/register`
- `POST /api/auth/login`
- `GET /api/auth/me`
- `POST /api/auth/logout`
- `GET /api/layouts`
- `GET /api/layouts/:id`
- `POST /api/layouts`
- `PUT /api/layouts/:id`
- `DELETE /api/layouts/:id`

`/api/layouts` endpoints require `Authorization: Bearer <token>`.

Sample create payload:

```json
{
  "name": "My Plan",
  "floors": 2,
  "rooms": [],
  "structures": []
}
```

Sample register payload:

```json
{
  "name": "Ashish",
  "email": "ashish@example.com",
  "password": "123456"
}
```

## Flutter Backend URL

Default API URL in app: `http://10.0.2.2:8000/api`.

To override at build/run time:

```bash
flutter run --dart-define=API_BASE_URL=http://localhost:8000/api
```

## Deploy Backend To Vercel

From project root:

```bash
vercel deploy backend -y
```

This repository includes `backend/vercel.json` for Node API routing.

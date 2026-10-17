# Call Monitor — Flutter + Node API

An authenticated telecaller dashboard with server-backed call logs, contacts, reports, recording uploads, and Android default-dialer onboarding.

## Run locally

1. In `Backend/`, copy `.env.example` to `.env` and set a long, random `JWT_SECRET`.
2. In `Backend/`, run `npm install`, then `npm start` to start the API.
3. Run `flutter pub get`.
4. Run the client with a reachable API URL, for example: `flutter run --dart-define=API_BASE_URL=https://api.example.com`.

## Included

- Email/password registration and sign-in, with the session stored securely on device.
- Authenticated calls, contacts, recordings, dashboard, analytics, and spam-report API endpoints.
- Name/number search, call-type/date filtering, contact management, tap-to-dial, dashboard metrics, and date-range reports.
- Authorized recording-file upload with required consent confirmation.
- Android system request for a user to select the app as their default dialer.

## Platform and privacy boundary

The default-dialer role is selected only by the user through Android's system UI. It does **not** grant a third-party app access to capture normal cellular-call audio. This project accepts recordings only from authorized/app-owned capture providers and requires an explicit consent confirmation before upload. Do not describe uploaded, manual, or provider-owned records as automatic system-call capture.

Call logs, contacts, and recordings are sensitive personal data. Before production deployment, use HTTPS, a managed database/object store, encryption at rest, retention/deletion controls, backups, rate limiting, password-reset and email-verification flows, a privacy policy, and jurisdiction-specific legal advice on recording consent. iOS does not provide general access to the Phone app's full cellular call history.

## Development storage

For development, `Backend/server.js` stores JSON data in `Backend/data/store.json` and recording files in `Backend/uploads/`. These are not production storage; replace them with a managed database and private object store before deployment.

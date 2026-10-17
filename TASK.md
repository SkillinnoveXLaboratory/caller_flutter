# Telecaller Call Monitor — implementation checklist

## Product boundary

The product supports app-entered and provider/VoIP-owned calls. Android default-dialer onboarding is offered, but default-dialer status does not grant a third-party app permission to silently capture normal cellular call audio. A recording may be uploaded only after explicit consent and from a supported capture source.

## Tasks

- [x] Create the Node/Express API with email/password authentication and JWT access control.
- [x] Add persistent server-side users, contacts, call logs, recordings, spam reports, notifications, and analytics endpoints.
- [x] Add safe media upload, authenticated media retrieval, validation, and environment configuration.
- [x] Replace the local-only Flutter data layer with an authenticated API client and secure session storage.
- [x] Add email/password sign-in and registration screens.
- [x] Implement dashboard, calls, date/name/number search, contacts, recordings, analytics, settings, and consent-oriented permissions screens.
- [x] Add Android default-dialer role request bridge and required user-visible permission handling.
- [x] Replace the obsolete counter test with relevant tests.
- [x] Install dependencies, format, analyze, run tests, and fix findings.
- [x] Update the deployment and platform-limitations documentation.

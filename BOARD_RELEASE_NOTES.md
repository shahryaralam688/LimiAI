# Board / TestFlight release notes (template)

Use this list when uploading a build. Replace items with what is verified in that build.

## Requires API support

- **Sign in with Apple**: iOS posts to `POST /client/apple/login` with JSON `identity_token` (JWT) and `user` (Apple user identifier). The API must return the same app token shape as Google login: `{ "data": { "token": "<jwt>" } }` (nested `data.data.token` is also parsed).
- **Limi voice**: `POST /limi-ai/session` with header `Authorization: Bearer <app token>` must return `{ "key": "<ephemeral key for OpenAI Realtime>" }`.

## User-visible changes (recent)

- Sign in with Apple uses the dedicated route above (no longer mixed with Google credentials).
- Voice screen uses `Authorization: Bearer …` for the session endpoint; clearer errors if sign-in or session fails.
- AI store and integration screens are Limi-branded (no third-party model branding on primary surfaces).
- Voice UI: Limi-first copy; Capabilities instead of Upgrade; channel picker uses theme colors.

## Checklist before board demo

1. Install build from TestFlight on a device with microphone permission.
2. Complete Google or Apple sign-in; confirm Home loads.
3. Open voice / Limi AI; confirm session connects (depends on API above).
4. Open a multi-channel device; confirm channel list and CCT/RGB styling.

# Phased roadmap: AI, voice, and always-on Limi

Delivery-oriented breakdown after board-ready auth, voice errors, and Limi-first UI (see BOARD_RELEASE_NOTES.md).

## Phase A — Developer-configurable endpoints (1–2 sprints)

- In-app Settings, Developer (hidden behind build flag or PIN): base URL for API, optional overrides for LLM, speech, and TTS if exposed by backend.
- Store secrets in Keychain; never commit keys.
- Backend continues to own OpenAI Realtime proxy and ephemeral keys for production.

## Phase B — Provider breadth (2+ sprints)

- OpenAI Realtime: harden reconnect, logging, and model selection if backend adds fields.
- Optional TTS: ElevenLabs or similar only if product and legal approve; route audio through backend when possible.

## Phase C — Ambient presence (multi-sprint, product + legal)

- Clear user consent and mic indicator for always-listening modes; respect iOS background audio and privacy guidelines.
- Wake-word-free interaction may require device-side DSP or server VAD; align with firmware and security.

## Phase D — Ecosystem

- Anthropic and other LLMs: unify behind one backend abstraction so the app stays a thin client.

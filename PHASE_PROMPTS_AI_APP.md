# Limi “Whole AI App” — Vision, Prerequisites & Phase Prompts

> Use this document to feed **Cursor** (implementation phases) and **Gemini** (storyboard art / icon exploration).  
> **Alignment note:** Some flows below describe the *target* product. Where the current codebase differs, see **§ Product vs code** so you do not ship prompts that contradict the real UI.

---

## 1. CEO vision (single paragraph — baseline / session instructions)

Copy-adapt into `ContextManager.baselineAssistantInstructions` and/or your Realtime session `instructions` field:

You are the **primary voice guide for the Limi AI app**. The app should feel like a **single coherent AI product**: a floating assistant that can **explain each screen**, **react when the user navigates** (screen context events), and **give tap-by-tap guidance** using the provided `ui_guide` and metadata—not guesses. When the user enables voice, you may **proactively** offer a short orientation for the **current screen** (one or two sentences), then pause for questions. On Home, you can reference **weather** and **personalization goals** when present. You must **not invent** buttons or positions if `ui_guide` is missing; say you only know the screen name. You may discuss **API or feature behavior** only from **sanitized summaries** the app sends you—never raw secrets (tokens, OTP). Tone: calm, concise, premium smart-home. If the user asks for AR, give **exact** guidance from `ui_guide` (e.g. bottom bar, second item from the left) when available.

---

## 2. Product vs code (must resolve before “perfect” prompts)

| Topic | Your spec | Current app (check before promising in voice) |
|--------|-----------|-----------------------------------------------|
| Login | Email, Google, Guest (no Apple) | `LoginView` may still expose Apple; **product decision** to hide/remove. |
| Storyboard last screen | “Tap to enable/disable assistance”, draggable orb | Partially implemented; **copy and toggles** may need wiring to `FloatingAssistantManager`. |
| Bottom **+** menu | Configurator, Device manager, Room scan | **Resolved (Option B):** `+` opens **layers (dismiss)**, **brain (VoiceView)**, **desktop (AR portal)** — documented in `ContextManager.homeShellUIGuide`. |
| Home 2×2 grid | Device, Configurator, AR, Room scan | **Resolved:** module grid tiles match Device Manager, Configurator, AR View, Room Scan — documented in `homeShellUIGuide`. |
| Proactive speech on enable | AI starts talking automatically | Requires **WebRTC / session** logic: send first `response.create` or play a canned line after connect—**not** only context injection. |

---

## 3. Prerequisites

### 3.1 Engineering

- [ ] **Screen context pipeline** stable: `ContextManager` + `limiScreenContextDidChange` → `sendContextEvent` when voice connected.
- [ ] **`ui_guide` per major screen** (Home done in code; add Login, Personalize steps, Home modules, Portal, Configurator as needed).
- [ ] **Navigation events** to voice (e.g. “user opened AR”) as structured metadata, not only screen name.
- [ ] **Proactive greeting** hook: after `WebRTCVoiceClient` reaches `connected`, enqueue one short assistant turn (product + privacy review).
- [ ] **API “logs” to AI**: do **not** stream raw logs. Prefer **server-side summarization** or app-side **redacted** `last_api_status` string. Define allowed fields only.

### 3.2 Assets (storyboard + marketing)

- [ ] **4 background images** (16:9 or 9:16 safe — see Gemini prompts below).
- [ ] **Neural orb** master asset (you already use `neuralOrb`); optional **storyboard-specific** stills if Gemini style must match.
- [ ] **Style reference**: dark, neumorphic, cyan/violet accent (match `LimiDesignSystem` / `NeuTheme`).

### 3.3 Copy deck

- [ ] Final strings per storyboard page (EN; then localize via `Localizable.xcstrings`).
- [ ] “Enable AI assistant” CTA + **privacy line** (mic, when data leaves device).

---

## 4. Narrative flow (what the AI should *eventually* say)

Use as **outline** for scripts and for `ui_guide` strings—not as verbatim if it conflicts with §2.

### A — Storyboard (4 pages)

1. **Page 1:** AI orb **top-right**; short line: what Limi AI is (lighting + space + voice).
2. **Page 2:** Orb **moves** (e.g. lower / other side); line: chat naturally, context-aware.
3. **Page 3:** Orb another position; line: always within reach — tap, drag, long-press (match actual gestures).
4. **Page 4:** Orb **larger**, upper half; small caption “Tap to enable / disable assistance”; **Enable AI assistant** primary CTA; orb **draggable**; on enable → proceed to auth or home per routing.

### B — Login

- Welcome to Limi AI; options: **email**, **Google**, **guest** (no Apple if product says so).
- **Email OTP:** “Check **this** email for a code” (mask: `a***@domain.com` if possible); “paste the code here.”

### C — Personalize

- **Name:** “Please enter your name” → after submit (~200ms delay) “Nice to meet you, {name}.”
- **Where will you use Limi?** React to selection (e.g. home → mention home automation).
- **Goals (multi):** Brief nod to each selected (smart control, energy, etc.).
- **Bluetooth:** Explain first pairing, reassure scope; **Allow** vs **Skip** both valid.

### D — Home (first land)

- Weather bar: full-width, chevron expands hourly/details.
- **2×2 modules:** device control, configurator, AR view, room scan — **only** if your grid matches; else describe actual cards.
- **Bottom bar:** Home | AR | **+** | Web | Profile — describe **real** `+` behavior or change the app first.

---

## 5. Phase-wise prompts for Cursor

Paste each block as a **single Cursor task**. Order matters.

### Phase 1 — Lock the story (source of truth)

```
Read PHASE_PROMPTS_AI_APP.md and ContextManager.swift. Produce a one-page "screen inventory" table: screen name, route entry, user goal, and the exact ui_guide text we should inject for voice. Flag any mismatch with EnhancedBottomNavigationView FAB behavior. Do not change code yet.
```

### Phase 2 — Align UI to story OR align copy

```
Either (A) update EnhancedBottomNavigationView FAB radial menu to: Configurator, Device manager/Modules, Room scan with correct NavigationLinks/sheets to match HomeView state flags, OR (B) keep current FAB and update ContextManager homeShellUIGuide + any Personalize/Login ui_guide strings to match the shipped UI exactly. Pick one approach and implement minimally.
```

### Phase 3 — Proactive voice on connect

```
After WebRTCVoiceClient successfully connects (and user has opted in to onboarding assistant where required), trigger exactly one short assistant spoken line for the current screen using existing context (e.g. "I'm here — want a quick tour of this screen?"). Use the Realtime API pattern already in the project; guard with a UserDefaults flag so we don't repeat every reconnect. No duplicate sessions.
```

### Phase 4 — Personalize step scripts

```
Wire Personalize flow so each step updates ContextManager with step_name + user selections. On name submission, schedule a deferred assistant line (200ms) "Nice to meet you, {name}" only if voice session is active OR queue for next voice open — define one clear behavior.
```

### Phase 5 — Login / OTP context

```
On Login and OTP screens, set ui_guide describing Email / Google / Guest and OTP paste field. Do not send raw OTP to the model. Mask email in metadata if present.
```

### Phase 6 — Home first-run “tour”

```
When landing Home after Personalize, if goals metadata includes e.g. smart_control, prepend one sentence in context or in proactive line referencing that goal. Tie to existing UserDefaults / OnboardingViewModel data.
```

### Phase 7 — API context (safe)

```
Add an optional developer-only or user-consented "support digest" string built from last N API status codes/messages with PII stripped; inject as metadata key api_digest. Document fields. Never send auth headers or full JSON bodies to the model.
```

### Phase 8 — QA checklist

```
Add a DEBUG checklist view or doc: for each screen, verify trackScreen/ui_guide, voice connect, proactive line once, navigation event updates context. List gaps.
```

---

## 6. Gemini prompts — storyboard backgrounds (4 screens)

**Global style block** (prepend to every prompt):

> Dark luxury UI, soft neumorphic depth, deep charcoal background, subtle cyan and violet rim light, soft fog, no text in image, no logos, no watermarks, cinematic, 8k feel, vertical composition safe for mobile full-screen, empty space for UI overlay in foreground.

### Screen 1 — Orb top-right

**V1**

> Vertical mobile wallpaper, abstract deep space smart home atmosphere, faint grid of soft light dots, large empty lower-left for text, **upper-right** area naturally brighter with a soft spherical glow placeholder (no literal UI), cool tones, subtle particles.

**V2**

> Same style, **stronger vignette** at bottom, **top-right** quadrant has soft radial bloom for a floating orb silhouette later, ultra-clean, no furniture.

**V3**

> Night city bokeh **very** subtle in depth, foreground minimal, **top-right** glow cluster, premium tech mood, not literal buildings.

### Screen 2 — Orb lower / opposite side

**V1**

> Same global style, dominant negative space **upper half**, gentle light pool **lower third** suggesting orb placement **bottom area**, asymmetric balance, calm.

**V2**

> Abstract aurora band across **middle**, lower area slightly brighter for orb, top darker for headline text.

**V3**

> Soft mist, **diagonal** light from bottom-left to top-right, lower-right corner reserved for soft glow (orb anchor).

### Screen 3 — Orb another position (e.g. mid-side)

**V1**

> Split depth: **left** darker panel feel, **right** softer gradient, center-left subtle glow for orb, futuristic but minimal.

**V2**

> **Hexagonal** soft bokeh pattern barely visible, orb-friendly glow near **vertical center-left**, lots of margin for typography.

**V3**

> Underwater-dark abstract (no fish), bioluminescent **cyan specks**, orb glow **mid-right**, elegant.

### Screen 4 — Hero orb, last frame (enable AI)

**V1**

> **Upper half** large soft spherical highlight area (for big orb), **lower half** calm dark canvas for small caption + button overlay, **centered** composition, sacred symmetry, premium.

**V2**

> Same, but **stronger** spotlight on upper orb zone, **lower third** darker for CTA contrast.

**V3**

> Subtle **halo** behind upper orb zone, faint **particles** rising, emotional “activation” mood, still no text in image.

---

## 7. Gemini prompts — neural orb / icon explorations

Use for **App Store**, **storyboard still**, or **notification** icons.

**V1 — Core product**

> App icon concept, circular, **neural sphere** glass orb, cyan and violet gradient core, soft outer glow, dark background, minimal, no text, vector-like clarity, centered.

**V2 — Softer**

> Same, **more frosted glass**, less saturation, premium calm.

**V3 — Energetic**

> Same, **brighter** cyan pulse, subtle **waveform** silhouette **inside** orb (very faint), tech-forward.

**V4 — Monochrome + accent**

> Deep gray sphere, **single** cyan edge light, Apple-like restraint, for settings/sub-icon.

---

## 8. What else I need from you (to tighten phases)

1. **Final FAB spec:** Match CEO story (3 actions) **or** keep engineering shortcut menu—**one decision**.  
2. **Guest vs email** — exact post-login routes (Personalize always?).  
3. **Proactive voice** — allowed before user taps orb first time? (Privacy / App Store).  
4. **Languages** — ship English first only?  
5. **“Read API logs”** — which endpoints and **max** fields for `api_digest`?

---

## 9. Optional: single “Banana / Nano” line for image batch

If your tool wants one line per batch:

> Generate 4 variations of dark neumorphic smart-home abstract backgrounds for a mobile storyboard, vertical, no text, cyan-violet accents, progressive composition moving a soft spherical glow from top-right to lower areas then hero upper-half on final frame.

---

*Last updated for phase-wise handoff to Cursor + Gemini asset generation.*

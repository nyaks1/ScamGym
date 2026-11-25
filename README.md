# ScamGym

**Train your instincts. The AI plays the scammer. Plain code keeps the score.**

ScamGym is a scam-awareness trainer built for South Africa. It gives you three things:

| Mode | What it does |
| --- | --- |
| **Train** | Gemini role-plays a scammer from a fictional scenario. You reply as if the message were real, then get a deterministic weigh-in. |
| **Check a link** | Paste a suspicious URL. ScamGym scores its structural warning signs **without opening it**. |
| **Check a message** | Paste an SMS, WhatsApp or email. ScamGym matches scam language patterns, extracts every link and checks each one. |

> **Simulation only.** Every scenario uses invented organisations, people, phone numbers and links. Nothing in the training mode represents a real bank, agency, courier, retailer or person. Links use reserved `example.com` / `example.test` domains.

---

## Why it is built this way

- **The model writes the scam; it never grades you.** Gemini generates the in-character messages and can declare which red flag it just planted. The score comes from deterministic Python: regex action detection, planted-flag matching, fixed penalties and bonuses.
- **The checkers work offline.** Link and message verdicts are computed in pure Python. They do not need an API key, and a model cannot change the verdict. Gemini only adds an optional plain-language explanation.
- **Fictional by construction.** Prompts restrict the model to the scenario's invented details, an output sanitiser strips real brands/URLs/phone numbers, and tests assert that every scenario link stays on a reserved demo domain.
- **Privacy by default.** No accounts, no database. Rounds live in server memory and expire after 45 minutes. Raw message text is not sent to Gemini for triage explanations.

---

## How a round works

```text
Flutter client                FastAPI server                     Gemini
     |                              |                               |
     |-- POST /api/rounds --------->|  create in-memory round       |
     |<-- opening message ----------|                               |
     |                              |                               |
     |-- POST .../messages -------->|  detect actions in your text  |
     |                              |-- chat + tool calls --------->|
     |                              |<-- scam reply, flag/action ---|
     |<-- reply, turn, score -------|  sanitise + re-validate       |
     |                              |                               |
     |-- POST .../events ---------->|  record a link click          |
     |-- POST .../score ----------->|  compute deterministic score  |
     |<-- weigh-in -----------------|                               |
```

1. Pick one of five scenarios. The opening SMS/WhatsApp is pre-written and already contains some red flags.
2. Reply like it is real. Refuse, question, verify, or fall for it. Links are clickable, but ScamGym **never opens them**; a click is recorded as an event.
3. The model plants at most one new red flag per turn and may record an action it sees. The server re-checks every model hint against your own words.
4. Weigh in. You get a score out of 100, a grade, the flags you spotted and missed, your risky/good actions, a score breakdown and concrete advice.

---

## Scenarios

| ID | Title | Fictional organisation | Channel | Difficulty |
| --- | --- | --- | --- | --- |
| `kalahari-bank` | The fraud desk that calls you | Kalahari Bank | SMS | 2 |
| `ubuntu-grants` | Free money with a small fee | Ubuntu Grants Agency | SMS | 1 |
| `parcelpal` | The parcel that isn't yours | ParcelPal Couriers | SMS | 1 |
| `kudu-rewards` | You've won something you never entered | KuduMart | SMS | 2 |
| `talentbridge` | The job that charges you | TalentBridge Recruitment | WhatsApp | 3 |

Each scenario is a self-contained Python module in `backend/app/scenarios/`. Adding a scam type means adding a module and registering it; the engine, prompts and scorer do not change.

---

## Quick start

### Requirements

- Python **3.12+**
- Flutter **3.47+** / Dart **3.13+** (for the client)
- A Gemini API key (only needed for training and optional explanations)

### 1. Backend

```bash
cd backend
python3.12 -m venv .venv
source .venv/bin/activate          # Windows: .venv\Scripts\activate
pip install -r requirements.txt -r requirements-dev.txt

cp .env.example .env
# Edit .env and set GEMINI_API_KEY=...
chmod 600 .env

uvicorn app.main:app --reload --port 8080
```

- API docs: <http://localhost:8080/api/docs>
- Health: <http://localhost:8080/api/health>

Without a key the server still starts. `GET /api/health` reports `"ai": false`, training returns `503`, and the link/message checkers keep working.

### 2. Flutter client

The app lives in `frontend/` and targets **Android, iOS and web** from one codebase.

```bash
cd frontend
flutter pub get
flutter analyze
flutter test
```

#### Web development (separate dev server)

Run the backend on port 8080, then:

```bash
flutter run -d chrome --web-port=5000 \
  --dart-define=API_BASE=http://localhost:8080
```

Because the Flutter dev server is on a different origin, allow it in `backend/.env` and restart the backend:

```dotenv
CORS_ORIGINS=http://localhost:5000,http://127.0.0.1:5000
```

#### Web, served by FastAPI (recommended)

```bash
cd frontend
flutter build web --release --no-web-resources-cdn
```

`--no-web-resources-cdn` bundles CanvasKit locally so the app satisfies the server's strict `default-src 'self'` Content-Security-Policy without external CDN requests. The server automatically serves `frontend/build/web` at <http://localhost:8080/> when that build exists. Restart the backend after building. Same-origin means no CORS configuration is needed.

#### Android emulator

```bash
cd frontend
flutter run -d emulator-5554 \
  --dart-define=API_BASE=http://10.0.2.2:8080
```

`10.0.2.2` is the host machine as seen from the Android emulator. A physical phone needs your computer's LAN address (for example `http://192.168.1.20:8080`) and that address added to `frontend/android/app/src/main/res/xml/network_security_config.xml`, or an HTTPS backend. The included cleartext exception is for local development only.

#### iOS

```bash
cd frontend
flutter run -d <device> --dart-define=API_BASE=http://localhost:8080
```

For a physical device, use your machine's LAN address or an HTTPS backend.

### 3. Use the checkers without the app

```bash
curl -s http://localhost:8080/api/check/link \
  -H 'Content-Type: application/json' \
  -d '{"url":"https://paypa1.com/login"}' | python -m json.tool

curl -s http://localhost:8080/api/check/message \
  -H 'Content-Type: application/json' \
  -d '{"text":"KALAHARI BANK: Reply with the OTP we just sent to cancel the transfer."}' \
  | python -m json.tool
```

---

## Configuration

All configuration is environment-based. Copy `backend/.env.example` to `backend/.env`; `.env` is git-ignored and must never be committed.

| Variable | Default | Purpose |
| --- | --- | --- |
| `GEMINI_API_KEY` | empty | Server-side Gemini key. Empty disables training and AI explanations. |
| `GEMINI_MODEL` | `gemini-3.5-flash-lite` | Model used for the scammer and triage coach. |
| `HOST` | `0.0.0.0` | Bind address. |
| `PORT` | `8080` | Bind port. |
| `TRUST_PROXY` | `0` | Set to `1` behind a trusted reverse proxy so rate limits see real client IPs. |
| `ROUND_TTL_MINUTES` | `45` | In-memory round lifetime after the last activity. |
| `CORS_ORIGINS` | empty | Comma-separated allowed origins, only for a separately hosted client. |

The Flutter client also accepts a compile-time API base:

```bash
flutter run --dart-define=API_BASE=http://localhost:8080
```

Leave `API_BASE` unset for the same-origin web build.

---

## API

Base path: `/api`. Interactive documentation: `/api/docs`.

| Method | Path | Purpose |
| --- | --- | --- |
| `GET` | `/api/health` | Server status, whether Gemini is configured, model, scenario count. |
| `GET` | `/api/scenarios` | Public scenario metadata. Red flags and personas stay hidden. |
| `POST` | `/api/rounds` | Start a round. Body: `{"scenario_id": "kalahari-bank"}`. |
| `GET` | `/api/rounds/{id}` | Current round state, transcript and score. |
| `POST` | `/api/rounds/{id}/messages` | Send a learner reply. Body: `{"text": "..."}` (max 1200 chars). |
| `POST` | `/api/rounds/{id}/events` | Record a client event. Body: `{"kind": "link_clicked", "url": "..."}`. |
| `POST` | `/api/rounds/{id}/score` | Compute and return the deterministic weigh-in. |
| `DELETE` | `/api/rounds/{id}` | Drop the round. Returns `204`. |
| `POST` | `/api/check/link` | Check one URL. Body: `{"url": "..."}` (max 2048 chars). |
| `POST` | `/api/check/message` | Check one message. Body: `{"text": "..."}` (max 5000 chars). |

### Round response

`POST /api/rounds` returns:

```json
{
  "round_id": "…",
  "scenario": {"id": "kalahari-bank", "title": "…", "flag_count": 6, "…": "…"},
  "opening": "KALAHARI BANK FRAUD DESK: …",
  "turn": 0,
  "max_turns": 8,
  "status": "active"
}
```

`POST /api/rounds/{id}/messages` returns the scammer reply plus `turn`, `max_turns`, `status` (`active`, `ended`, `scored`), an optional `score`, and `limit_reached`.

### Weigh-in

```json
{
  "score": 72,
  "grade": "C",
  "verdict": "Getting there. The scammer found some traction.",
  "summary": "4 of 6 planted red flags spotted. 1 risky action, 2 good moves.",
  "flags": {
    "planted": [{"id": "urgency", "label": "Manufactured urgency", "severity": "high", "spotted": true, "…": "…"}],
    "spotted": [],
    "missed": []
  },
  "actions": [{"kind": "clicked_link", "label": "Clicked a link", "points": -20, "source": "client"}],
  "breakdown": {"start": 100, "flag_bonus": 20, "flag_penalty": -8, "action_penalty": -20, "action_bonus": 0},
  "advice": ["…"],
  "turn_count": 5
}
```

### Checker response

Link and message reports share this shape (message reports also include `links`, `phone_numbers`, `link_verdicts` and `official_domain_seen`):

```json
{
  "input": "…",
  "score": 70,
  "verdict": "critical",
  "verdict_label": "Almost certainly a scam link",
  "severity": "high",
  "findings": [
    {"id": "brand_lookalike", "label": "Brand lookalike domain", "detail": "…", "weight": 45, "severity": "high"}
  ],
  "advice": ["…"],
  "not_checked": ["Whether the site is live", "…"],
  "ai_explanation": "Optional plain-language explanation, or null"
}
```

Verdicts: `low`, `caution`, `high`, `critical`. Links can also be `demo` (reserved practice domain) or `invalid` (not a usable URL). Messages can be `invalid` for empty input.

### Errors

| Status | Meaning |
| --- | --- |
| `404` | Unknown scenario, or round expired/deleted. |
| `409` | Round already finished/scored, or turn limit reached. |
| `422` | Invalid body, empty text or unsupported event. |
| `429` | Rate limit hit. Wait a minute. |
| `502` | Gemini/provider failure. The round is rolled back. |
| `503` | Gemini is not configured on this server. |

Rate limits are in-memory and per client IP: 20 round starts/min, 40 messages/min, 30 checks/min. Events and scoring share the message bucket. The API also rejects request bodies over 64 KB.

---

## How scoring works

The score starts at **100** and is clamped to **0–100**.

### Red flags

- **+5 per planted flag you spotted**, capped at **+20**. A flag counts as spotted when your own messages match its spot patterns.
- **Missed flags** cost **4** (low), **6** (medium) or **8** (high) each.
- Only flags actually planted are scored. Opening flags count from the start.

### Actions

Actions are detected from your own words, with conservative rules (a refusal such as "I won't share the OTP" is not scored as sharing). The model may suggest an action, but the server only accepts it if your message supports it. Link clicks are authoritative from the client and are never taken from the model.

| Risky action | Points |
| --- | ---: |
| Shared a card PIN or password | −40 |
| Shared card details | −40 |
| Gave remote access | −40 |
| Shared a one-time PIN | −35 |
| Sent money | −30 |
| Installed an app on request | −25 |
| Clicked a link | −20 |
| Shared an ID number | −20 |
| Shared personal details | −15 |
| Called the number in the message | −10 |
| Agreed to keep it secret | −10 |

| Good move | Points |
| --- | ---: |
| Verified through an independent channel | +10 |
| Refused the request | +8 |
| Reported or blocked the sender | +6 |
| Asked a verification question | +4 |

Good moves are capped at **+18**. Repeated kinds count once.

### Grades

| Score | Grade | Meaning |
| ---: | --- | --- |
| 95–100 | A+ | Scam-proof |
| 90–94 | A | Scam-proof |
| 80–89 | B | Sharp |
| 70–79 | C | Getting there |
| 60–69 | D | Shaken |
| 50–59 | E | Badly rattled |
| 0–49 | F | You got hooked — run it again |

Sensitive values are never stored. Evidence for an OTP, PIN, card or ID is redacted before it reaches round state or any response.

---

## What the checkers look for

### Link checker

The URL is parsed as text and never fetched. Signals include:

- Lookalike domains (`paypa1.com`, `capitec-secure.top`) and brands inside longer tokens
- Raw IP addresses, punycode (`xn--…`), mixed-alphabet hosts
- URL shorteners (`bit.ly`, `tinyurl.com`, …)
- High-risk domain endings (`.top`, `.xyz`, `.click`, `.zip`, `.tk`, …)
- Hidden text before `@`, unusual ports, excessive subdomains, very long hosts
- `http://` or a missing scheme
- Credential/payment wording in the path (`login`, `verify`, `otp`, `pay`, `claim`, …)
- Executables and Android packages (`.apk`, `.exe`, …)
- Dangerous schemes such as `javascript:` or `file:`
- Reserved practice domains (`example.com`, `example.test`), reported as `demo`

The report always lists what it **cannot** see: whether the site is live, who registered it, whether it serves malware, and reputation data.

### Message checker

Plain Python matches the language patterns scams rely on, including:

- Requests for an OTP, PIN, password, CVV, card, ID or banking details
- Manufactured urgency, threats, account-freeze language
- Payment/fee requests, prizes, grants, courier stories, tax refunds
- Job offers with upfront fees, investment/crypto promises, romance language
- Secrecy requests, pressure to move to WhatsApp/Telegram
- Remote-access tools or app installs, credential-harvesting links
- Generic greetings, premium-rate numbers, "reply YES", SIM-swap stories
- All-caps shouting, excessive exclamation marks
- Every embedded link is run through the link checker
- A brand name that does not match any link domain (strong impersonation signal)

For the optional explanation, only matched signal labels, hosts and advice are sent to Gemini. The raw message text is not.

---

## Tests

```bash
cd backend
.venv/bin/pytest
```

The suite covers deterministic scoring, action detection, redaction, link triage, message triage, scenario validation, the HTTP contract, offline behaviour, security headers and round lifecycle. It runs without a Gemini key or network access.

```bash
cd frontend
flutter test
flutter analyze
```

---

## Project layout

```text
ScamGym/
├── backend/
│   ├── app/
│   │   ├── main.py              FastAPI app, security headers, web serving
│   │   ├── api.py               HTTP routes and rate limiting
│   │   ├── config.py            environment configuration
│   │   ├── gemini.py            google-genai client + triage explanations
│   │   ├── engine/
│   │   │   ├── trainer.py       round orchestration and tool handling
│   │   │   ├── scoring.py       deterministic action detection + score
│   │   │   ├── rounds.py        in-memory round state and TTL
│   │   │   ├── prompts.py       scammer and coach prompts
│   │   │   ├── safety.py        refusal detection + output sanitiser
│   │   │   ├── triage_link.py   offline link checker
│   │   │   └── triage_message.py offline message checker
│   │   └── scenarios/           five fictional scenario modules
│   ├── tests/                   pytest suite (72 tests)
│   ├── requirements.txt
│   ├── requirements-dev.txt
│   └── .env.example
├── frontend/                    Flutter app (Android, iOS, web)
│   ├── lib/
│   │   ├── main.dart
│   │   ├── api.dart
│   │   ├── models.dart
│   │   ├── theme.dart
│   │   ├── screens/             Train, Check a link, Check a message
│   │   └── widgets/             shared cards, score ring, footer
│   ├── assets/fonts/            bundled DejaVu fonts + licence
│   ├── web/
│   └── test/
└── README.md
```

---

## Safety, privacy and POPIA

ScamGym is a training tool, not an official bank, government or law-enforcement service.

- **No real data needed.** Never type real card numbers, PINs, OTPs or ID numbers. The UI says so; the prompt tells the model to refuse them; the scorer redacts them.
- **Rounds are ephemeral.** State is held in server memory only, expires after 45 minutes of inactivity, and disappears when the process restarts. There is no database, no account and no analytics.
- **Chat text goes to Gemini.** Training messages are sent to Google's Gemini API so the model can reply. Triage explanations send only signal labels, hosts and advice, not the raw message.
- **Cross-border processing.** Gemini processes data outside South Africa. For a public deployment, add a clear privacy notice and consent step, and put a data-processing agreement in place with Google. POPIA's minimisation and security conditions apply.
- **No content is logged.** Application logs record error types, not message bodies.
- **Fiction is enforced.** Scenario validation and tests keep links on reserved domains and phone numbers on reserved/placeholder ranges. The output sanitiser strips real brands, URLs and numbers if the model drifts.
- **If money has moved,** call your bank's official fraud line immediately and report the message to the organisation it pretends to come from. This app cannot recover funds.

---

## Security notes

- The Gemini key lives only on the server. It is never sent to the client.
- `.env` is git-ignored. **If a key has been shared in chat, a screenshot or a commit, rotate it.**
- Security headers include CSP, `X-Content-Type-Options`, `X-Frame-Options`, `Referrer-Policy`, `Permissions-Policy` and HSTS behind HTTPS.
- Request bodies are capped at 64 KB; text fields have explicit length limits.
- CORS is disabled by default and only enabled for origins you list.
- There is no authentication. Do not expose a public deployment without adding authentication, tighter per-user limits and monitoring.

---

## Limits

- The checkers are **offline and structural**. They do not query reputation feeds, DNS history or page content, and a clean result is not a guarantee.
- The model can still behave unexpectedly. The prompt and sanitiser reduce risk but do not make it deterministic.
- In-memory rounds mean a single-process deployment. Multiple workers or instances would not share state.
- Rate limits are per process and reset on restart.
- The Flutter web client must be built before the FastAPI server can serve it at `/`; otherwise `/` returns a small JSON pointer to the API docs.
- The Android cleartext exception is for local development only. Production should use HTTPS.

---

## Status

- [x] Python 3.12 + FastAPI backend with the official `google-genai` SDK
- [x] Five fictional scenarios with hidden red flags and fictional-detail enforcement
- [x] Deterministic scoring, action detection, redaction, grades and advice
- [x] Offline link checker and message checker
- [x] Optional Gemini explanations that cannot change a verdict
- [x] In-memory rounds with TTL, rate limits and security headers
- [x] Flutter client for Android, iOS and web (Train / Check a link / Check a message)
- [x] 72 backend tests passing
- [x] Flutter `analyze` / `test` / web release build verified
- [ ] Docker image and hosted deployment
- [ ] Public privacy notice and consent flow for a hosted instance

---

## Credits

Built with [FastAPI](https://fastapi.tiangolo.com/), [Google Gemini](https://ai.google.dev/) via the official [`google-genai`](https://github.com/googleapis/python-genai) Python SDK, and [Flutter](https://flutter.dev/). The client bundles IBM Plex Sans and IBM Plex Mono; their licence is in `frontend/assets/fonts/IBMPlex-LICENSE.txt`.

ScamGym is a buildathon project. Add a licence before publishing or redistributing it.

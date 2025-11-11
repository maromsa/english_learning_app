# english_app_final

Gamified English-learning Flutter app with optional AI coaching and camera powered vocabulary building.

## Getting Started

This project targets families and teachers who want fun English vocabulary
practice with camera, speech, and mini-game experiences. The app boots with a
travel map that unlocks levels as kids earn stars.

### Core Features

- Dynamic world map loaded from assets with multi-stage progression and star requirements.
- AI-assisted pronunciation feedback and optional smart camera word discovery powered by Gemini (when configured).
- Spark's Adventure Lab generates custom story quests, challenges, and pep talks for any unlocked world using Gemini.
- Spark Chat Buddy offers live conversational practice with voice support, adaptive prompts, and vocabulary scaffolding.
- AI Practice Packs instantly assemble three-part mini sessions tailored to the learner's energy level, time, and focus words.
- Daily reward streaks, in-app shop, and achievements with celebratory animations.
- Offline-friendly word cache with fast startup even when Cloudinary is unreachable.
- Settings screen to toggle dark mode, reset progress, and clear cached word packs.

### Prerequisites

- Flutter 3.24 or newer
- Dart 3.5 or newer
- Firebase CLI (for backend scripts)

### Configuration

Sensitive keys are never checked into the repository. Supply them at runtime via
`--dart-define` when launching the app or running scripts. The `lib/app_config.dart`
helper exposes the values at runtime.

At startup the app looks for secrets in this order:

1. Explicit `--dart-define` flags (works on every platform, including web/CI).
2. A local `.env` file loaded via `flutter_dotenv` (only on mobile/desktop builds).
3. Environment variables exposed by the underlying platform.

| Dart define | Feature | Notes |
| --- | --- | --- |
| `GEMINI_PROXY_URL` | Hosted Gemini proxy endpoint (Firebase Functions / Cloud Run) | Required. All AI features go through this endpoint; if it is unreachable, the app surfaces an error instead of falling back. |
| `GOOGLE_TTS_API_KEY` | Server-quality Hebrew TTS | Optional. Falls back to on-device TTS if omitted. |
| `PIXABAY_API_KEY` | Bulk word uploader scripts | Required for `dart run scripts/upload_words.dart`. |
| `FIREBASE_USER_ID_FOR_UPLOAD` | Bulk word uploader scripts | Target document owner in Firestore. |
| `CLOUDINARY_CLOUD_NAME` / `CLOUDINARY_API_KEY` / `CLOUDINARY_API_SECRET` | Remote word sync (Cloudinary) and tooling | Required for pulling remote word packs. |

Example dev run:

```bash
flutter run \
  --dart-define=GEMINI_PROXY_URL=https://<region>-<project>.cloudfunctions.net/geminiProxy \
  --dart-define=CLOUDINARY_CLOUD_NAME=your_cloud \
  --dart-define=CLOUDINARY_API_KEY=your_api_key \
  --dart-define=CLOUDINARY_API_SECRET=your_secret
```

#### Local .env helper

To avoid repeating the flags in local builds, copy `.env.example` to `.env`, fill in your secrets, and use the provided wrapper script:

```bash
cp .env.example .env
echo "GEMINI_PROXY_URL=https://<region>-<project>.cloudfunctions.net/geminiProxy" >> .env

./scripts/flutterw run -d chrome
```

The script sources `.env`, injects the necessary `--dart-define` flags when missing, and falls back to any existing environment variables. On mobile/desktop builds the runtime also loads `.env` directly, so both approaches work. For Flutter web, the `.env` file is never bundled—use `./scripts/flutterw` locally or pass the defines explicitly. In CI you can keep using plain `flutter` with explicit `--dart-define` flags so secrets stay in your secret manager.

#### Server-side Gemini proxy (Firebase Functions / Cloud Run)

Keep your Gemini key on the server by deploying the bundled proxy under `functions/`:

1. `cd functions`
2. `npm install`
3. Store the key securely:  
   - **Firebase Functions**: `firebase functions:secrets:set GEMINI_API_KEY`  
   - **Cloud Run (via Cloud Build)**: configure `GEMINI_API_KEY` as a secret/env var in your deployment pipeline.
4. For Firebase, build and deploy:
   ```bash
   npm run build
   firebase deploy --only functions:geminiProxy
   ```
   For Cloud Run, package `functions/src/index.ts` into your service entrypoint (the code exports `geminiProxy` as an HTTP handler).
5. Confirm the published HTTPS URL. The Flutter app automatically targets `https://us-central1-<project-id>.cloudfunctions.net/geminiProxy`, so no extra flags are needed unless you front the function with a custom domain. In that case set both `GEMINI_PROXY_URL` and (optionally) `AI_IMAGE_VALIDATION_URL` to your public URL.

The proxy supports three operations:
- **Image identification** (`mode: "identify"`): returns the primary object name for camera capture.
- **Image validation** (default payload): answers whether an image matches a requested word and returns confidence.
- **Text generation** (`mode: "text"` / `"story"`): powers Spark's adventure stories and other Gemini prompts on the server.

Because the mobile/web client now talks to your proxy, the Gemini key never ships with the app binary—users only see the public endpoint you control.

### CI without live Gemini

For automated CI builds or preview deployments, provide a reachable Gemini proxy endpoint. If the proxy is unavailable the AI-dependent tests will fail fast with clear errors (no local stubs remain). A common pattern is to host a staging Cloud Function and expose its URL as `GEMINI_PROXY_URL` in your CI secrets.

Scripts can be executed in the same fashion, e.g.:

```bash
dart run scripts/upload_words.dart \
  --define=PIXABAY_API_KEY=your_pixabay_key \
  --define=FIREBASE_USER_ID_FOR_UPLOAD=your_user_id
```

### Artwork regeneration

The fallback lesson artwork is generated from OpenMoji icons with a small set of custom illustrations. Run `python3 scripts/generate_word_images.py` whenever you need to rebuild the assets under `assets/images/words/`. See `docs/ICON_ATTRIBUTION.md` for licence details.

## Continuous Integration

### GitHub Pages preview (free)

Pushes to the `main` branch trigger the `Deploy Flutter Web to GitHub Pages` workflow. The job builds the Flutter web bundle and publishes it to GitHub Pages so anyone can open the latest `main` build in a browser for manual testing.

To turn it on:

- In the repository settings, open **Pages** and select **GitHub Actions** as the deployment source (this creates the `github-pages` environment the workflow targets).
- Merge to `main` or run the workflow manually via the **Run workflow** button. The deploy job comment includes the public URL once publishing completes.

If you want the published build to include AI features, store the relevant values as repository or organization secrets (e.g. `GEMINI_PROXY_URL`, `CLOUDINARY_*`, `GOOGLE_TTS_API_KEY`). The workflow automatically forwards any non-empty secret to the build via `--dart-define`. Missing secrets simply disable the corresponding feature in the web bundle.

### Optional: Appetize uploads

If you need a mobile emulator experience, the `Upload Debug Build to Appetize` workflow can build a debug APK and push it to Appetize. The job is skipped unless the required secrets are present.

Set these repository secrets to enable it (Appetize offers a limited free tier):

- `APPETIZE_API_TOKEN`: API token generated from your Appetize account. The workflow authenticates against `https://api.appetize.io/v1/apps` with this token.
- `APPETIZE_PUBLIC_KEY` (optional but recommended): The public key of the Appetize app you want to overwrite. Leave it empty the first time you run the workflow; copy the `publicKey` output from the workflow run and add it as the secret so subsequent runs update the same hosted build.

Both workflows also support manual triggers via the `workflow_dispatch` event.

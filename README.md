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

| Dart define | Feature | Notes |
| --- | --- | --- |
| `GEMINI_API_KEY` | AI-powered pronunciation feedback & photo recognition | Optional. When missing the app gracefully falls back to manual play. |
| `ENABLE_GEMINI_STUB` | Spark's Adventure Lab offline stub | Optional. Set to `true` in CI to serve deterministic stories without exposing a real Gemini key. |
| `GOOGLE_TTS_API_KEY` | Server-quality Hebrew TTS | Optional. Falls back to on-device TTS if omitted. |
| `PIXABAY_API_KEY` | Bulk word uploader scripts | Required for `dart run scripts/upload_words.dart`. |
| `FIREBASE_USER_ID_FOR_UPLOAD` | Bulk word uploader scripts | Target document owner in Firestore. |
| `CLOUDINARY_CLOUD_NAME` / `CLOUDINARY_API_KEY` / `CLOUDINARY_API_SECRET` | Remote word sync (Cloudinary) and tooling | Required for pulling remote word packs. |

Example dev run:

```bash
flutter run \
  --dart-define=GEMINI_API_KEY=your_key \
  --dart-define=CLOUDINARY_CLOUD_NAME=your_cloud \
  --dart-define=CLOUDINARY_API_KEY=your_api_key \
  --dart-define=CLOUDINARY_API_SECRET=your_secret
```

#### Automatic local injection

To avoid repeating the flags, copy `.env.example` to `.env`, fill in your secrets, and use the provided wrapper:

```bash
cp .env.example .env
echo "GEMINI_API_KEY=your_key" >> .env

./scripts/flutterw run -d chrome
```

The script sources `.env`, injects `--dart-define=GEMINI_API_KEY=...` when missing, and falls back to any existing environment variables. It works with other Flutter subcommands too (e.g. `./scripts/flutterw build web`). In CI you can keep using plain `flutter` with explicit `--dart-define` flags so secrets stay in your secret manager.

### CI without live Gemini

For automated CI builds or preview deployments where secrets are unavailable, enable Spark's deterministic stub stories instead of providing a real Gemini key:

```bash
flutter test \
  --dart-define=ENABLE_GEMINI_STUB=true
```

The app, widget tests, and web builds will still complete successfully, and the AI adventure screen shows offline copy suitable for demos.

When you do need live Gemini features in CI, store the key as an encrypted secret (for example `GEMINI_API_KEY`) and pass it via `--dart-define=GEMINI_API_KEY=$GEMINI_API_KEY` so nothing is hard-coded in your configuration files.

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

No additional secrets are required for the GitHub Pages deployment.

### Optional: Appetize uploads

If you need a mobile emulator experience, the `Upload Debug Build to Appetize` workflow can build a debug APK and push it to Appetize. The job is skipped unless the required secrets are present.

Set these repository secrets to enable it (Appetize offers a limited free tier):

- `APPETIZE_API_TOKEN`: API token generated from your Appetize account. The workflow authenticates against `https://api.appetize.io/v1/apps` with this token.
- `APPETIZE_PUBLIC_KEY` (optional but recommended): The public key of the Appetize app you want to overwrite. Leave it empty the first time you run the workflow; copy the `publicKey` output from the workflow run and add it as the secret so subsequent runs update the same hosted build.

Both workflows also support manual triggers via the `workflow_dispatch` event.

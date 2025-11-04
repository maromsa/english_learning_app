# english_app_final

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Continuous Integration

### Automatic Appetize Uploads

Pushes to the `main` branch trigger the `Upload Debug Build to Appetize` GitHub Actions workflow. The job builds a debug Android APK and uploads it to Appetize so the latest `main` build can be tested in a browser-based emulator.

#### Required GitHub secrets

- `APPETIZE_API_TOKEN`: API token generated from your Appetize account. The workflow authenticates against `https://api.appetize.io/v1/apps` with this token.
- `APPETIZE_PUBLIC_KEY` (optional but recommended): The public key of the Appetize app you want to overwrite. Leave it empty the first time you run the workflow; copy the `publicKey` output from the workflow run and add it as the secret so subsequent runs update the same hosted build.

The workflow also supports manual triggers from the **Run workflow** button on GitHub via the `workflow_dispatch` event.

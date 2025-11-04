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

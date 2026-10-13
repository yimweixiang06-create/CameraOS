# Build an unsigned IPA without owning a Mac

This workflow performs a **build only** on a GitHub-hosted macOS runner. It does not run simulator/device tests and does not sign the app. Sideloadly will perform signing with your Apple ID on your own computer.

## Run it

1. Create or open a GitHub repository you control.
2. Upload the contents of this project ZIP to the repository root. The `.github/workflows/build-unsigned-ipa.yml` file must be included. Commit the files to `main` or `master`.
3. Open the repository's **Actions** tab and select **Build unsigned iOS IPA**. Click **Run workflow** if it has not started automatically.
4. Wait for the workflow to finish. If it fails, open the run and inspect `xcodebuild.log` in the artifact when available; a failed compile means there is no usable IPA yet.
5. In the successful run's **Artifacts** section, download `FilmStyleCamera-unsigned-IPA` and unzip the downloaded artifact bundle to get `FilmStyleCamera-unsigned.ipa`.
6. On your Windows PC, open Sideloadly, connect your iPhone, select the IPA, enter your Apple ID in Sideloadly, and start sideloading. Never share your Apple ID password or verification code in chat.

## Important limitations

- The IPA is intentionally unsigned. Sideloadly must sign it for your device.
- This source is an unfinished starter app: video recording, filtered live preview, and true portrait/panorama modes are not implemented.
- The workflow has not been run from this environment, so build success is not guaranteed. It only packages the IPA if Xcode reports a successful build and the `.app` output exists.
- A free Apple ID sideload generally needs periodic re-signing and may have restrictions. Sideloading does not make an unfinished feature work.

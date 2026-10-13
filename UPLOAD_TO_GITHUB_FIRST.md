# Upload this project correctly

1. Extract this ZIP.
2. Upload the extracted contents (not the ZIP itself and not the outer folder) to the root of your GitHub repository.
3. The repository root should show `FilmStyleCamera.xcodeproj`, `FilmStyleCameraApp.swift`, `Assets.xcassets`, and `.github`.
4. Ensure `.github/workflows/build-unsigned-ipa.yml` exists.
5. The workflow does not enforce a separate logo-file check; Xcode will use whatever app-icon assets are configured in the project.
6. If Git reports `early EOF`, `unpack-objects failed`, or `RPC failed`, the source upload/push was interrupted. Retry uploading/committing the missing files; these are Git transfer errors, not an Xcode compiler error.

The workflow creates an unsigned IPA for later signing in Sideloadly. It does not sign with your Apple ID.

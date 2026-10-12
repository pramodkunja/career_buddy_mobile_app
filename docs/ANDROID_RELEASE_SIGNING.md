# Android Release Signing

Status as of Phase 7A: **no production upload keystore exists yet** — this
was explicitly checked, not assumed. A generic `upload-keystore.jks` was
found in the development machine's home directory but could not be
attributed to this app (unrelated, undated metadata, sitting next to an
unrelated `royalhrms-upload-keystore.jks` for a different project) and was
confirmed with the project owner to not be the authorized key. Until a real
keystore is created and `android/key.properties` populated by whoever holds
that authority, release builds (`scripts/build_release.sh` /
`scripts/build_release_aab.sh`) keep signing with the Android debug key —
the exact same behavior this project already had before Phase 7A. Nothing
in this document changes that until the steps below are actually performed.

## Why this matters

Once an app is first published to Google Play signed with a given key, every
future update must be signed with that *same* key (or use Play App Signing,
which still requires an initial upload key). There is no supported way to
"reset" this after the fact. Generating the wrong key, or losing it, is a
release-blocking, largely irreversible mistake — so this step is
deliberately manual, not automated, and the password is never typed into an
AI session or committed to git.

## 1. Generate the upload keystore (run this yourself, in your own terminal)

```bash
keytool -genkey -v \
  -keystore ~/career-buddy-upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias career_buddy_upload
```

- Pick a storage location outside this repo (e.g. your home directory, or a
  password manager's attachment storage) — never inside `Mobile_app/`.
- `keytool` will prompt for a keystore password, a key password (can be the
  same value), and the certificate's distinguished-name fields (org, city,
  etc. — these end up in the public certificate, not secret).
- **Back this file up somewhere durable and private before anything else.**
  If it's lost, you lose the ability to publish updates to this app under
  its existing Play Store listing, permanently.

## 2. Create `android/key.properties` (git-ignored — confirmed in
   `android/.gitignore`, already present before this phase)

```properties
storePassword=<the keystore password you chose above>
keyPassword=<the key password you chose above>
keyAlias=career_buddy_upload
storeFile=/absolute/path/to/career-buddy-upload-keystore.jks
```

This file is read by `android/app/build.gradle.kts`, which was updated in
Phase 7A to build a `release` signing config from it automatically — see
that file's comments. No other code change is needed. Do not quote the
values; do not commit this file (verify with `git status` that it shows as
untracked/ignored before any commit).

## 3. Build and verify

```bash
scripts/build_release_aab.sh
```

The script prints the exact `jarsigner` command to confirm the resulting
`.aab` is actually signed with your new key (not the debug key) — run it and
check the printed certificate's `CN`/fingerprint before uploading anything
to the Play Console. An `.apk` (`scripts/build_release.sh`) uses the same
signing config and can be checked the same way with
`apksigner verify --print-certs`.

## What Phase 7A did and did not do

- Did: add the conditional signing-config wiring in
  `android/app/build.gradle.kts` (falls back to debug signing when
  `key.properties` is absent — verified by rebuilding both the `.apk` and
  the new `.aab` and confirming both still report `CN=Android Debug`,
  i.e. unchanged behavior).
- Did: add `scripts/build_release_aab.sh` (Play Store requires an `.aab`;
  the existing `build_release.sh` only produces an `.apk`, which is for
  direct install/testing, not Play Store upload).
- Did not: generate a keystore, touch `android/key.properties` (it does not
  exist), or sign anything with a production key.
- Did not: upload anything, or claim the current build is production-signed
  — it is not, and won't be until steps 1–2 above are done by whoever holds
  signing authority for this app.

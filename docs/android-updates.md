# Android Updates

Streamed uses public GitHub Releases for free, direct APK updates. The app checks
the latest release, shows an update dialog, downloads the signed APK, and opens
the Android installer. Android still requires the user to confirm the install.

## One-time signing setup

Create a release key locally and keep the file private:

```powershell
keytool -genkeypair -v -keystore streamed-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias streamed
```

Convert it to base64 and add these GitHub repository secrets:

- `KEYSTORE_BASE64`
- `KEYSTORE_PASSWORD`
- `KEY_ALIAS`
- `KEY_PASSWORD`

The signing key must be reused for every future release. Losing it prevents
Android from installing updates over an existing app.

## Publish a release

Either push a version tag:

```powershell
git tag v1.0.1
git push origin v1.0.1
```

Or run the **Android Release** workflow manually and enter a version such as
`1.0.1`. The workflow builds a signed release APK, creates a GitHub Release,
and uploads `update.json` plus the APK.

Every release must use a higher version than the previous release. The normal
push workflow still creates debug APK artifacts for development; those are not
valid update packages for users.

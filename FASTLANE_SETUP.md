# Fastlane Setup Documentation

This document describes the Fastlane configuration for building and releasing the React Native Expo app.

## Overview

Fastlane has been configured to automate the build and release process for both Android and iOS platforms.

## Files Created

### 1. `Gemfile`
Manages Ruby dependencies including Fastlane.

**Usage:**
```bash
bundle install  # Install dependencies
bundle exec fastlane [platform] [lane]  # Run Fastlane commands
```

### 2. `.ruby-version`
Specifies Ruby version 2.7.6 for consistency across environments.

### 3. `fastlane/Fastfile`
Contains the automation lanes for Android and iOS builds.

### 4. `fastlane/Appfile`
Configures app identifiers and Apple Developer account settings.

### 5. `package.json` (updated)
Added `prebuild` script for Expo prebuild command.

### 6. `app.json` (updated)
Added platform-specific configurations:
- iOS bundle identifier: `com.testmobileapp`
- Android package: `com.testmobileapp`
- Build numbers and version codes

## Available Lanes

### Android

#### `fastlane android release`
Builds Android App Bundle (AAB) and uploads to Google Play Console.

**Requirements:**
- `ANDROID_KEYSTORE_BASE64` - Base64-encoded keystore file (or `ANDROID_KEYSTORE_PATH`)
- `ANDROID_KEYSTORE_PASSWORD` - Keystore password
- `ANDROID_KEY_ALIAS` - Key alias
- `ANDROID_KEY_PASSWORD` - Key password
- `GOOGLE_PLAY_SERVICE_KEY` - Google Play service account JSON key (as string)

**What it does:**
1. Decodes keystore from base64 (if provided)
2. Builds release AAB with signing
3. Uploads to Google Play internal track as draft

#### `fastlane android build`
Builds Android APK for testing (no upload).

### iOS

#### `fastlane ios release`
Builds iOS IPA and uploads to TestFlight.

**Requirements:**
- `APP_STORE_CONNECT_API_KEY_ID` - App Store Connect API Key ID
- `APP_STORE_CONNECT_ISSUER_ID` - Issuer ID
- `APP_STORE_CONNECT_API_KEY` - API Key content
- `FASTLANE_MATCH_DEPLOY_KEY` - (Optional) Match deploy key for code signing
- `GITHUB_RUN_NUMBER` - (Optional) Build number from CI

**What it does:**
1. Creates App Store Connect API key file
2. Sets up code signing (with Match if configured)
3. Increments build number
4. Installs CocoaPods dependencies
5. Builds IPA for App Store distribution
6. Uploads to TestFlight

#### `fastlane ios build`
Builds iOS IPA for testing (no upload).

## CI/CD Integration

### Required Environment Variables

The following environment variables should be set in your CI/CD pipeline:

**Android:**
- `ANDROID_KEYSTORE_BASE64` - Base64-encoded Android keystore
- `ANDROID_KEYSTORE_PASSWORD` - Keystore password
- `ANDROID_KEY_ALIAS` - Key alias
- `ANDROID_KEY_PASSWORD` - Key password
- `GOOGLE_PLAY_SERVICE_KEY` - Google Play service account JSON (as string)

**iOS:**
- `APP_STORE_CONNECT_API_KEY_ID` - App Store Connect API Key ID
- `APP_STORE_CONNECT_ISSUER_ID` - Issuer ID
- `APP_STORE_CONNECT_API_KEY` - API Key content (p8 file content)
- `APPLE_ID` - (Optional) Apple ID email
- `APPLE_TEAM_ID` - (Optional) Apple Developer Team ID
- `APP_STORE_CONNECT_TEAM_ID` - (Optional) App Store Connect Team ID
- `FASTLANE_MATCH_DEPLOY_KEY` - (Optional) SSH deploy key for Match
- `MATCH_PASSWORD` - (Optional) Password for Match certificates

**General:**
- `CI` - Set to `true` in CI environment
- `GITHUB_RUN_NUMBER` - Build number (automatically set in GitHub Actions)

### CI Pipeline Steps

Your CI/CD pipeline should include these steps:

1. **Install dependencies:**
   ```bash
   npm install
   bundle install
   ```

2. **Run Expo prebuild:**
   ```bash
   npm run prebuild --clean
   ```

3. **Build and release Android:**
   ```bash
   bundle exec fastlane android release
   ```

4. **Build and release iOS:**
   ```bash
   bundle exec fastlane ios release
   ```

## Local Development

### Prerequisites

1. Install Ruby (version 2.7.6 or compatible)
2. Install Bundler: `gem install bundler`
3. Install dependencies: `bundle install`

### Running Locally

1. **Generate native projects:**
   ```bash
   npm run prebuild --clean
   ```

2. **Build Android locally:**
   ```bash
   bundle exec fastlane android build
   ```

3. **Build iOS locally:**
   ```bash
   bundle exec fastlane ios build
   ```

## Assets

The `assets` directory should contain app icons and splash screens. See `assets/README.md` for specifications.

**Currently:** The app uses default Expo icons and a colored splash screen. You should add custom assets before production release.

## Code Signing

### Android

The app uses a keystore for signing. In CI, the keystore is decoded from the `ANDROID_KEYSTORE_BASE64` environment variable.

**To create a keystore locally:**
```bash
keytool -genkeypair -v -storetype PKCS12 -keystore release.keystore -alias your-key-alias -keyalg RSA -keysize 2048 -validity 10000
```

### iOS

The app can use either:
1. **Fastlane Match** - Centralized certificate management (recommended for teams)
2. **Manual code signing** - Xcode managed signing

Configure Match by setting up a private Git repository and running:
```bash
bundle exec fastlane match init
```

## Troubleshooting

### Common Issues

1. **"Could not locate Gemfile"**
   - Run `bundle install` in the project root

2. **"Could not find fastlane configuration"**
   - Ensure the `fastlane` directory exists with `Fastfile` and `Appfile`

3. **Android signing errors**
   - Verify keystore path and passwords are correct
   - Check that `ANDROID_KEYSTORE_BASE64` is properly encoded

4. **iOS workspace not found**
   - Run `pod install` in the `ios` directory first
   - The Fastfile will automatically run CocoaPods

5. **TestFlight upload fails**
   - Verify App Store Connect API key credentials
   - Check that the bundle identifier is registered in App Store Connect

## Bundle Identifier

Current bundle identifier: `com.testmobileapp`

**To change:**
1. Update `app.json`:
   - `expo.ios.bundleIdentifier`
   - `expo.android.package`
2. Update `fastlane/Appfile`:
   - `app_identifier`
   - `package_name`
3. Run `npm run prebuild --clean` to regenerate native projects

## Next Steps

1. **Add custom app icons and splash screens** (see `assets/README.md`)
2. **Set up code signing certificates** for iOS
3. **Configure Google Play Console** and **App Store Connect**
4. **Test the build pipeline** in CI/CD
5. **Update version numbers** in `package.json` before each release

## Support

For Fastlane documentation, visit: https://docs.fastlane.tools
For Expo documentation, visit: https://docs.expo.dev

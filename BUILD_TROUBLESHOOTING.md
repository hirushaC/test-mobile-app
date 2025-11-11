# Build & Release Troubleshooting Guide

This guide documents common build and release errors, their root causes, and solutions.

## Table of Contents
- [Critical Issues Fixed](#critical-issues-fixed)
- [Environment Variables](#environment-variables)
- [Android Build Errors](#android-build-errors)
- [iOS Build Errors](#ios-build-errors)
- [Fastlane Errors](#fastlane-errors)
- [CI/CD Pipeline Errors](#cicd-pipeline-errors)
- [General Troubleshooting](#general-troubleshooting)

---

## Critical Issues Fixed

### ✓ iOS Bundle Identifier Mismatch (FIXED)
**Previous Error:** Xcode project had `org.name.testmobileapp` while app.json had `com.testmobileapp`
**Solution:** Updated Xcode project to use `com.testmobileapp` everywhere
**Files Modified:** `ios/testmobileapp.xcodeproj/project.pbxproj`

### ✓ Android Release Signing Uses Debug Keystore (FIXED)
**Previous Error:** Release builds were signed with debug keystore
**Solution:** Updated build.gradle to accept injected signing properties from Fastlane
**Files Modified:** `android/app/build.gradle`

### ✓ Fastlane Path Issues (FIXED)
**Previous Error:** Fastfile used incorrect relative paths
**Solution:** All paths now use `../` prefix since Fastfile runs from `fastlane/` directory
**Files Modified:** `fastlane/Fastfile`

### ✓ Keystore Corruption from Base64 (FIXED)
**Previous Error:** `DerInputStream.getLength(): lengthTag=107, too big`
**Solution:** Changed to binary mode (`'wb'`) when writing decoded keystore
**Files Modified:** `fastlane/Fastfile`

### ✓ gradlew Permission Denied (FIXED)
**Previous Error:** `Permission denied - android/gradlew`
**Solution:** Added `chmod +x` in Fastfile and fixed git permissions
**Files Modified:** `fastlane/Fastfile`, `android/gradlew` (git permissions)

---

## Environment Variables

### Required for Android Release

```bash
# Keystore signing (provide ONE of these)
ANDROID_KEYSTORE_BASE64       # Base64-encoded keystore (recommended for CI)
# OR
ANDROID_KEYSTORE_PATH         # Path to keystore file (for local builds)

# Keystore credentials
ANDROID_KEYSTORE_PASSWORD     # Keystore password
ANDROID_KEY_ALIAS             # Key alias
ANDROID_KEY_PASSWORD          # Key password

# Google Play upload
GOOGLE_PLAY_SERVICE_KEY       # JSON string (not file path!) of service account key
```

### Required for iOS Release

```bash
# App Store Connect API (required)
APP_STORE_CONNECT_API_KEY_ID  # API Key ID from App Store Connect
APP_STORE_CONNECT_ISSUER_ID   # Issuer ID from App Store Connect
APP_STORE_CONNECT_API_KEY     # P8 file content (not file path!)

# Manual Code Signing (Match not configured)
# For manual signing, configure certificates and provisioning profiles in Xcode
# Or set up Fastlane Match separately

# Optional for Match (if configuring later)
# FASTLANE_MATCH_DEPLOY_KEY   # SSH private key for Match git repository
# MATCH_GIT_URL               # Git repository URL for Match
# MATCH_PASSWORD              # Passphrase for Match encryption
```

### Auto-Set by CI

```bash
CI=true                       # Indicates CI environment
GITHUB_RUN_NUMBER             # Used for auto-incrementing build numbers
```

### Validation

Fastfile now validates required environment variables before build. If any are missing, you'll get:
```
❌ Missing required environment variables: ANDROID_KEYSTORE_PASSWORD, ANDROID_KEY_ALIAS
```

---

## Android Build Errors

### Error: "Task ':app:signReleaseBundle' FAILED"

**Possible Causes:**
1. Keystore file corrupted (wrong base64 encoding)
2. Wrong keystore password
3. Key alias doesn't exist in keystore
4. Wrong key password

**Solutions:**
1. **Check base64 encoding:**
   ```bash
   # Encode keystore correctly
   cat release.keystore | base64 -w 0 > keystore.base64
   ```

2. **Verify keystore:**
   ```bash
   keytool -list -v -keystore release.keystore -storepass YOUR_PASSWORD
   ```

3. **Check alias exists:**
   ```bash
   keytool -list -keystore release.keystore -storepass YOUR_PASSWORD
   # Should list your key alias
   ```

### Error: "Execution failed for task ':app:bundleRelease'"

**Possible Causes:**
1. ProGuard/R8 stripping required classes
2. Missing dependencies
3. Version conflicts

**Solutions:**
1. **Check ProGuard rules** in `android/app/proguard-rules.pro`
2. **Run with more verbose output:**
   ```bash
   cd android && ./gradlew bundleRelease --stacktrace --info
   ```

### Error: "Could not find com.android.tools.build:gradle:X.X.X"

**Solution:**
Update `android/build.gradle` with correct Android Gradle Plugin version:
```gradle
dependencies {
    classpath("com.android.tools.build:gradle:8.1.0")
}
```

### Error: Version Code Conflict

**Error:** `Upload failed: APK specifies a version code that has already been used`

**Solution:**
Version code now auto-increments using `GITHUB_RUN_NUMBER`:
```gradle
versionCode (System.getenv("GITHUB_RUN_NUMBER") as Integer ?: 1)
```

For manual builds, increment manually in `android/app/build.gradle`

---

## iOS Build Errors

### Error: "No signing identity found"

**Possible Causes:**
1. Provisioning profile doesn't match bundle identifier
2. Certificates not installed
3. Xcode automatic signing conflicts with Fastlane

**Solutions:**
1. **Verify bundle identifier matches:**
   - app.json: `com.testmobileapp`
   - Xcode project: `com.testmobileapp` ✓ (now fixed)

2. **Manual signing setup:**
   - Open Xcode
   - Select project → Signing & Capabilities
   - Ensure correct Team selected
   - Download provisioning profiles

3. **Check certificates in Keychain Access:**
   ```bash
   security find-identity -v -p codesigning
   ```

### Error: "Workspace not found"

**Error:** `ios/testmobileapp.xcworkspace` doesn't exist

**Solution:**
Run CocoaPods to generate workspace:
```bash
cd ios
pod install
cd ..
```

The Fastfile now automatically runs `cocoapods` before building.

### Error: "Scheme 'testmobileapp' not found"

**Solutions:**
1. **Ensure scheme is shared:**
   - Open Xcode
   - Product → Scheme → Manage Schemes
   - Check "Shared" for testmobileapp scheme

2. **Verify scheme exists:**
   ```bash
   ls ios/testmobileapp.xcodeproj/xcshareddata/xcschemes/
   # Should show testmobileapp.xcscheme
   ```

### Error: "Build number increment failed"

**Error:** Path to xcodeproj not found

**Solution:**
Fixed in Fastfile with correct relative path:
```ruby
increment_build_number(
  xcodeproj: "../ios/testmobileapp.xcodeproj",  # ✓ Correct path
  build_number: ENV["GITHUB_RUN_NUMBER"] || "1"
)
```

### Error: "TestFlight upload authentication failed"

**Possible Causes:**
1. API key file malformed
2. Wrong API key ID or Issuer ID
3. API key doesn't have App Manager role

**Solutions:**
1. **Verify API key format:**
   ```json
   {
     "key_id": "YOUR_KEY_ID",
     "issuer_id": "YOUR_ISSUER_ID",
     "key": "-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----"
   }
   ```

2. **Check API key roles in App Store Connect:**
   - Users and Access → Keys
   - Key should have "App Manager" or "Admin" role

---

## Fastlane Errors

### Error: "Could not find action, lane or variable 'load_json'"

**Status:** ✓ FIXED

**Previous Issue:** `load_json` is not a built-in Fastlane action

**Solution:** Replaced with native Ruby JSON parsing:
```ruby
require 'json'
package_json = File.read("../package.json")
package = JSON.parse(package_json)
version = package["version"]
```

### Error: "Could not locate Gemfile"

**Status:** ✓ FIXED

**Solution:** Created `Gemfile` in project root:
```ruby
source "https://rubygems.org"
gem "fastlane", "~> 2.228"
```

Run `bundle install` before using Fastlane.

### Error: "Could not find fastlane configuration files"

**Status:** ✓ FIXED

**Solution:** Created `fastlane/` directory with:
- `Fastfile` - Build and release lanes
- `Appfile` - App configuration
- `Pluginfile` - Fastlane plugins (empty)

### Error: "Missing required environment variables"

**New Feature:** Fastfile now validates environment variables before build

**Example Error:**
```
❌ Missing required environment variables: ANDROID_KEYSTORE_PASSWORD, GOOGLE_PLAY_SERVICE_KEY
```

**Solution:** Set all required environment variables before running Fastlane (see Environment Variables section)

---

## CI/CD Pipeline Errors

### Error: "npm run prebuild failed"

**Error:** `Missing script: "prebuild"`

**Status:** ✓ FIXED

**Solution:** Added to `package.json`:
```json
{
  "scripts": {
    "prebuild": "expo prebuild"
  }
}
```

### Error: "Permission denied - gradlew"

**Status:** ✓ FIXED

**Solutions Applied:**
1. Fastfile runs `chmod +x ../android/gradlew`
2. Git permissions fixed: `git update-index --chmod=+x android/gradlew`

### Error: "Xcode_16.2.app not found"

**Possible Issue:** CI workflow references Xcode version not available on runner

**Solution:**
Check available Xcode versions:
```bash
ls /Applications/ | grep Xcode
```

Update workflow to use available version:
```yaml
- name: Select Xcode
  run: sudo xcode-select -s /Applications/Xcode_15.0.app
```

### Error: "bundle install failed"

**Possible Causes:**
1. Gemfile.lock out of sync
2. Ruby version mismatch
3. Gem installation permissions

**Solutions:**
1. **Update Gemfile.lock:**
   ```bash
   bundle update
   ```

2. **Use correct Ruby version:**
   ```bash
   ruby --version  # Should match .ruby-version
   rbenv install 2.7.6
   rbenv local 2.7.6
   ```

### Error: Artifact upload fails

**Possible Causes:**
1. Build output path incorrect
2. Artifact doesn't exist

**Current Paths:**
- Android AAB: `android/app/build/outputs/bundle/release/app-release.aab`
- iOS IPA: `ios/build/testmobileapp.ipa` (generated by Fastlane)

**Verify build artifacts exist:**
```bash
ls -la android/app/build/outputs/bundle/release/
ls -la ios/build/
```

---

## General Troubleshooting

### Clean Build

When in doubt, clean everything:

**Android:**
```bash
cd android
./gradlew clean
cd ..
```

**iOS:**
```bash
cd ios
rm -rf build/
rm -rf Pods/
pod install
cd ..
```

**Node:**
```bash
rm -rf node_modules/
npm ci
```

**Metro:**
```bash
npx react-native start --reset-cache
```

### Check Configuration Consistency

**Bundle Identifiers:**
- `app.json` → `ios.bundleIdentifier`: `com.testmobileapp` ✓
- `app.json` → `android.package`: `com.testmobileapp` ✓
- `ios/testmobileapp.xcodeproj` → `PRODUCT_BUNDLE_IDENTIFIER`: `com.testmobileapp` ✓
- `fastlane/Appfile` → `app_identifier`: `com.testmobileapp` ✓

**Versions:**
- `package.json` → `version`: `1.0.0`
- `app.json` → `version`: `1.0.0`
- `android/app/build.gradle` → `versionName`: `"1.0"`
- `app.json` → `ios.buildNumber`: Auto-incremented by Fastlane
- `app.json` → `android.versionCode`: Auto-incremented using GITHUB_RUN_NUMBER

### Pre-Build Checklist

Before running a build, verify:

- [ ] All environment variables set (use validation script)
- [ ] Bundle IDs consistent across all files
- [ ] `npm install` completed successfully
- [ ] For iOS: `pod install` completed
- [ ] For Android: `android/gradlew` has execute permissions
- [ ] Git repository clean (no uncommitted changes to config files)
- [ ] Correct Xcode version selected (iOS only)

### Getting Help

1. **Check Fastlane logs:**
   ```bash
   # Logs are in fastlane/report.xml after each run
   ```

2. **Run with verbose output:**
   ```bash
   bundle exec fastlane android release --verbose
   bundle exec fastlane ios release --verbose
   ```

3. **Check Gradle logs:**
   ```bash
   cd android
   ./gradlew bundleRelease --stacktrace --info
   ```

4. **Check Xcode logs:**
   ```bash
   # In Xcode: View → Navigators → Reports
   # Or check ~/Library/Logs/gym/
   ```

---

## Firebase Configuration (Optional)

**Note:** Firebase is NOT currently configured in this app.

If you want to add Firebase:

1. **Add configuration files:**
   - Android: `android/app/google-services.json`
   - iOS: `ios/GoogleService-Info.plist`

2. **Update .gitignore:**
   Already configured to ignore these files ✓

3. **Base64 encode for CI:**
   ```bash
   cat google-services.json | base64 -w 0
   cat GoogleService-Info.plist | base64 -w 0
   ```

4. **Update CI workflow to decode and place files correctly**

---

## Quick Reference

### Run Local Builds

**Android:**
```bash
bundle exec fastlane android build
```

**iOS:**
```bash
bundle exec fastlane ios build
```

### Run Release Builds (CI)

**Android:**
```bash
bundle exec fastlane android release
```

**iOS:**
```bash
bundle exec fastlane ios release
```

### Common Commands

```bash
# Install dependencies
npm install
bundle install

# Generate native projects
npm run prebuild --clean

# iOS specific
cd ios && pod install && cd ..

# Check Fastlane version
bundle exec fastlane --version

# Update Fastlane
bundle update fastlane
```

---

## Version History

- **v1.0.0** - Initial release with all critical issues fixed
  - Fixed iOS bundle identifier mismatch
  - Fixed Android release signing
  - Fixed Fastfile path issues
  - Added environment variable validation
  - Added comprehensive ProGuard rules
  - Added auto-incrementing version codes/build numbers


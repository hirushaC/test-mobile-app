# CI/CD Best Practices Guide

Complete guide for setting up and optimizing your GitHub Actions CI/CD pipeline for React Native Expo app builds.

## Table of Contents
- [Overview](#overview)
- [GitHub Actions Workflow Structure](#github-actions-workflow-structure)
- [Environment Setup](#environment-setup)
- [Caching Strategy](#caching-strategy)
- [Build Optimization](#build-optimization)
- [Error Handling](#error-handling)
- [Artifact Management](#artifact-management)
- [Best Practices](#best-practices)

---

## Overview

Your CI/CD pipeline should:
1. Install dependencies efficiently
2. Generate native projects (Expo prebuild)
3. Build Android and iOS apps in parallel
4. Run Fastlane for release signing and store uploads
5. Upload artifacts to GitHub
6. Create GitHub releases

---

## GitHub Actions Workflow Structure

### Recommended Workflow File

```yaml
name: Build and Release

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
  workflow_dispatch:  # Allow manual triggers

jobs:
  # Job 1: Setup and validation
  setup:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'  # Use Node 20 for Expo SDK 54
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Run pre-build validation
        run: chmod +x scripts/pre-build-validate.sh && ./scripts/pre-build-validate.sh

  # Job 2: Android build
  android:
    needs: setup
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'

      - name: Setup Ruby
        uses: ruby/setup-ruby@v1
        with:
          ruby-version: '2.7.6'
          bundler-cache: true

      - name: Setup Java
        uses: actions/setup-java@v4
        with:
          distribution: 'temurin'
          java-version: '17'

      - name: Cache Gradle
        uses: actions/cache@v4
        with:
          path: |
            ~/.gradle/caches
            ~/.gradle/wrapper
          key: ${{ runner.os }}-gradle-${{ hashFiles('**/*.gradle*', '**/gradle-wrapper.properties') }}
          restore-keys: |
            ${{ runner.os }}-gradle-

      - name: Install dependencies
        run: npm ci

      - name: Expo Prebuild
        run: npm run prebuild -- --platform android --clean

      - name: Build and Release Android
        run: bundle exec fastlane android release
        env:
          ANDROID_KEYSTORE_BASE64: ${{ secrets.ANDROID_KEYSTORE_BASE64 }}
          ANDROID_KEYSTORE_PASSWORD: ${{ secrets.ANDROID_KEYSTORE_PASSWORD }}
          ANDROID_KEY_ALIAS: ${{ secrets.ANDROID_KEY_ALIAS }}
          ANDROID_KEY_PASSWORD: ${{ secrets.ANDROID_KEY_PASSWORD }}
          GOOGLE_PLAY_SERVICE_KEY: ${{ secrets.GOOGLE_PLAY_SERVICE_KEY }}

      - name: Upload Android AAB
        uses: actions/upload-artifact@v4
        with:
          name: android-release
          path: android/app/build/outputs/bundle/release/app-release.aab

  # Job 3: iOS build
  ios:
    needs: setup
    runs-on: macos-latest  # Required for iOS builds
    steps:
      - uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'

      - name: Setup Ruby
        uses: ruby/setup-ruby@v1
        with:
          ruby-version: '2.7.6'
          bundler-cache: true

      - name: Select Xcode
        run: sudo xcode-select -s /Applications/Xcode_15.0.app

      - name: Cache CocoaPods
        uses: actions/cache@v4
        with:
          path: ios/Pods
          key: ${{ runner.os }}-pods-${{ hashFiles('ios/Podfile.lock') }}
          restore-keys: |
            ${{ runner.os }}-pods-

      - name: Install dependencies
        run: npm ci

      - name: Expo Prebuild
        run: npm run prebuild -- --platform ios --clean

      - name: Install CocoaPods
        run: cd ios && pod install && cd ..

      - name: Build and Release iOS
        run: bundle exec fastlane ios release
        env:
          APP_STORE_CONNECT_API_KEY_ID: ${{ secrets.APP_STORE_CONNECT_API_KEY_ID }}
          APP_STORE_CONNECT_ISSUER_ID: ${{ secrets.APP_STORE_CONNECT_ISSUER_ID }}
          APP_STORE_CONNECT_API_KEY: ${{ secrets.APP_STORE_CONNECT_API_KEY }}
          MATCH_PASSWORD: ${{ secrets.MATCH_PASSWORD }}

      - name: Upload iOS IPA
        uses: actions/upload-artifact@v4
        with:
          name: ios-release
          path: |
            *.ipa
            ios/build/*.ipa

  # Job 4: Create GitHub Release
  release:
    needs: [android, ios]
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    steps:
      - uses: actions/checkout@v4

      - name: Download Android artifact
        uses: actions/download-artifact@v4
        with:
          name: android-release

      - name: Download iOS artifact
        uses: actions/download-artifact@v4
        with:
          name: ios-release

      - name: Get version from package.json
        id: version
        run: echo "VERSION=$(node -p "require('./package.json').version")" >> $GITHUB_OUTPUT

      - name: Create Release
        uses: softprops/action-gh-release@v1
        with:
          tag_name: v${{ steps.version.outputs.VERSION }}-${{ github.run_number }}
          files: |
            app-release.aab
            *.ipa
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

---

## Environment Setup

### Required Secrets

Set these in GitHub repository settings → Secrets and variables → Actions:

#### Android
```
ANDROID_KEYSTORE_BASE64       # Base64-encoded keystore file
ANDROID_KEYSTORE_PASSWORD     # Keystore password
ANDROID_KEY_ALIAS             # Key alias
ANDROID_KEY_PASSWORD          # Key password
GOOGLE_PLAY_SERVICE_KEY       # Google Play service account JSON (as string, not base64)
```

#### iOS
```
APP_STORE_CONNECT_API_KEY_ID  # API Key ID
APP_STORE_CONNECT_ISSUER_ID   # Issuer ID
APP_STORE_CONNECT_API_KEY     # P8 file content
MATCH_PASSWORD                # Match encryption password (if using Match)
```

### Creating Secrets

**Android Keystore:**
```bash
# Create keystore (if you don't have one)
keytool -genkeypair -v -storetype PKCS12 -keystore release.keystore -alias my-key-alias -keyalg RSA -keysize 2048 -validity 10000

# Base64 encode for GitHub Secret
cat release.keystore | base64 -w 0 > keystore.base64
# Copy contents of keystore.base64 to ANDROID_KEYSTORE_BASE64 secret
```

**Google Play Service Account:**
```bash
# Get JSON from Google Play Console → API access → Create service account
# Copy JSON content directly to GOOGLE_PLAY_SERVICE_KEY secret (DO NOT base64 encode!)
```

**App Store Connect API Key:**
```bash
# Download .p8 file from App Store Connect → Users and Access → Keys
cat AuthKey_XXXXXXXXXX.p8
# Copy contents (including BEGIN/END lines) to APP_STORE_CONNECT_API_KEY secret
```

---

## Caching Strategy

### NPM Cache
```yaml
- name: Setup Node.js
  uses: actions/setup-node@v4
  with:
    node-version: '20'
    cache: 'npm'  # Automatic npm caching
```

### Ruby/Bundler Cache
```yaml
- name: Setup Ruby
  uses: ruby/setup-ruby@v1
  with:
    ruby-version: '2.7.6'
    bundler-cache: true  # Automatic gem caching
```

### Gradle Cache
```yaml
- name: Cache Gradle
  uses: actions/cache@v4
  with:
    path: |
      ~/.gradle/caches
      ~/.gradle/wrapper
    key: ${{ runner.os }}-gradle-${{ hashFiles('**/*.gradle*', '**/gradle-wrapper.properties') }}
    restore-keys: |
      ${{ runner.os }}-gradle-
```

### CocoaPods Cache
```yaml
- name: Cache CocoaPods
  uses: actions/cache@v4
  with:
    path: ios/Pods
    key: ${{ runner.os }}-pods-${{ hashFiles('ios/Podfile.lock') }}
    restore-keys: |
      ${{ runner.os }}-pods-
```

**Benefits:**
- Reduces build time by 50-70%
- Saves GitHub Actions minutes (especially important for macOS runners)
- More consistent builds

---

## Build Optimization

### 1. Parallel Builds

Run Android and iOS builds in parallel:
```yaml
jobs:
  android:
    runs-on: ubuntu-latest
    # ... android steps

  ios:
    runs-on: macos-latest
    # ... ios steps
```

**Impact:** Cuts total build time in half

### 2. Use Correct Node Version

Expo SDK 54 requires Node 18+, recommend Node 20:
```yaml
- name: Setup Node.js
  uses: actions/setup-node@v4
  with:
    node-version: '20'  # Not '18'
```

### 3. Use npm ci Instead of npm install

```yaml
- name: Install dependencies
  run: npm ci  # Faster and more reliable than npm install
```

**Requirements:**
- `package-lock.json` must be committed
- `package-lock.json` must be up-to-date

### 4. Separate Prebuild for Each Platform

```yaml
# For Android
- name: Expo Prebuild
  run: npm run prebuild -- --platform android --clean

# For iOS
- name: Expo Prebuild
  run: npm run prebuild -- --platform ios --clean
```

**Benefit:** Avoids generating unnecessary platform files

### 5. macOS Runner Optimization

macOS runners are 10x more expensive than Ubuntu. Optimize:

```yaml
ios:
  runs-on: macos-latest
  if: github.event_name != 'pull_request'  # Skip iOS on PRs
```

Or use self-hosted runners for iOS builds if budget allows.

### 6. Xcode Version Selection

Always specify Xcode version explicitly:
```yaml
- name: Select Xcode
  run: sudo xcode-select -s /Applications/Xcode_15.0.app
```

Check available versions:
```bash
ls /Applications/ | grep Xcode
```

Current GitHub-hosted macOS runners typically have:
- Xcode 14.x
- Xcode 15.x
- Xcode 16.x (beta/release candidate)

---

## Error Handling

### 1. Continue on Error (Conditional)

For non-critical steps:
```yaml
- name: Upload to TestFlight
  continue-on-error: true
  run: bundle exec fastlane ios release
```

### 2. Retry Failed Steps

```yaml
- name: Build iOS
  uses: nick-fields/retry@v2
  with:
    timeout_minutes: 45
    max_attempts: 3
    command: bundle exec fastlane ios release
```

### 3. Slack/Discord Notifications

```yaml
- name: Notify on failure
  if: failure()
  uses: 8398a7/action-slack@v3
  with:
    status: ${{ job.status }}
    webhook_url: ${{ secrets.SLACK_WEBHOOK }}
```

### 4. Store Logs on Failure

```yaml
- name: Upload Fastlane logs
  if: failure()
  uses: actions/upload-artifact@v4
  with:
    name: fastlane-logs
    path: |
      fastlane/report.xml
      fastlane/**/*.log
```

---

## Artifact Management

### 1. Upload Build Artifacts

```yaml
- name: Upload Android AAB
  uses: actions/upload-artifact@v4
  with:
    name: android-release-${{ github.run_number }}
    path: android/app/build/outputs/bundle/release/app-release.aab
    retention-days: 30  # Auto-delete after 30 days
```

### 2. Upload Debug Symbols

```yaml
- name: Upload iOS dSYMs
  uses: actions/upload-artifact@v4
  with:
    name: ios-dsyms
    path: |
      *.dSYM.zip
      ios/build/*.dSYM.zip
```

### 3. Artifact Naming Convention

Use consistent naming:
```
android-release-{version}-{build-number}.aab
ios-release-{version}-{build-number}.ipa
```

---

## Best Practices

### 1. Pre-Build Validation

Run validation before expensive build operations:
```yaml
- name: Validate configuration
  run: |
    chmod +x scripts/pre-build-validate.sh
    ./scripts/pre-build-validate.sh
```

### 2. Separate Development and Production Workflows

**Development (Pull Requests):**
```yaml
on:
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - run: npm test
      - run: npm run lint
```

**Production (Main Branch):**
```yaml
on:
  push:
    branches: [main]

jobs:
  build-and-release:
    # Full build and upload
```

### 3. Version Tagging

Auto-create git tags:
```yaml
- name: Create tag
  run: |
    VERSION=$(node -p "require('./package.json').version")
    git tag v$VERSION-${{ github.run_number }}
    git push origin v$VERSION-${{ github.run_number }}
```

### 4. Conditional Steps

```yaml
- name: Upload to Google Play
  if: github.ref == 'refs/heads/main' && !contains(github.event.head_commit.message, '[skip-release]')
  run: bundle exec fastlane android release
```

### 5. Matrix Strategy for Multi-Environment Builds

```yaml
strategy:
  matrix:
    environment: [staging, production]
    platform: [android, ios]

steps:
  - name: Build ${{ matrix.platform }} for ${{ matrix.environment }}
    run: bundle exec fastlane ${{ matrix.platform }} ${{ matrix.environment }}
```

### 6. Security Best Practices

1. **Never commit secrets to repository**
2. **Use GitHub Secrets for all sensitive data**
3. **Rotate credentials regularly**
4. **Use least-privilege service accounts**
5. **Enable branch protection rules**

```yaml
# Branch protection settings (in GitHub UI):
# - Require pull request reviews
# - Require status checks to pass
# - Require signed commits
# - Include administrators
```

### 7. Workflow Triggers

```yaml
on:
  push:
    branches: [main]
    tags: ['v*']
  pull_request:
    branches: [main]
  schedule:
    - cron: '0 2 * * 1'  # Weekly Monday 2 AM build
  workflow_dispatch:  # Manual trigger
    inputs:
      platform:
        description: 'Platform to build'
        required: true
        type: choice
        options:
          - android
          - ios
          - both
```

### 8. Build Time Monitoring

```yaml
- name: Start timer
  id: timer
  run: echo "START_TIME=$(date +%s)" >> $GITHUB_OUTPUT

- name: Build
  run: bundle exec fastlane ios release

- name: Report build time
  run: |
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - ${{ steps.timer.outputs.START_TIME }}))
    echo "Build took $DURATION seconds"
```

---

## Troubleshooting CI/CD

### Common Issues

#### 1. "Permission denied - gradlew"

**Fix:** Ensure gradlew has execute permissions
```yaml
- name: Make gradlew executable
  run: chmod +x android/gradlew
```

Already fixed in Fastfile.

#### 2. "Xcode version not found"

**Fix:** Use available Xcode version
```yaml
- name: List available Xcode versions
  run: ls /Applications/ | grep Xcode

- name: Select Xcode
  run: sudo xcode-select -s /Applications/Xcode_15.0.app
```

#### 3. "bundle install failed"

**Fix:** Use `bundler-cache: true` in setup-ruby action
```yaml
- uses: ruby/setup-ruby@v1
  with:
    ruby-version: '2.7.6'
    bundler-cache: true
```

#### 4. "npm ci failed"

**Causes:**
- package-lock.json out of sync
- Wrong Node version

**Fix:**
```bash
# Locally
npm install
git add package-lock.json
git commit -m "Update package-lock.json"
```

#### 5. Build timeout

**Fix:** Increase timeout
```yaml
- name: Build
  timeout-minutes: 60  # Default is 360 (6 hours)
  run: bundle exec fastlane ios release
```

---

## Cost Optimization

### GitHub Actions Pricing (as of 2024)

- **Ubuntu runners:** $0.008/minute
- **macOS runners:** $0.08/minute (10x more expensive!)
- **Windows runners:** $0.016/minute

### Strategies

1. **Use Ubuntu for Android builds**
   ```yaml
   android:
     runs-on: ubuntu-latest  # Cheapest option
   ```

2. **Cache aggressively**
   - Saves 5-15 minutes per build
   - Reduces costs by 30-50%

3. **Skip iOS builds on PRs**
   ```yaml
   ios:
     if: github.ref == 'refs/heads/main'
   ```

4. **Use self-hosted runners**
   - One-time hardware cost
   - Unlimited minutes
   - Full control

5. **Limit concurrent builds**
   ```yaml
   concurrency:
     group: ${{ github.workflow }}-${{ github.ref }}
     cancel-in-progress: true  # Cancel old builds when new push
   ```

---

## Monitoring and Alerts

### 1. Build Status Badge

Add to README.md:
```markdown
![Build Status](https://github.com/username/repo/workflows/Build%20and%20Release/badge.svg)
```

### 2. Slack Integration

```yaml
- name: Slack Notification
  uses: rtCamp/action-slack-notify@v2
  env:
    SLACK_WEBHOOK: ${{ secrets.SLACK_WEBHOOK }}
    SLACK_MESSAGE: 'Build completed for version ${{ steps.version.outputs.VERSION }}'
```

### 3. GitHub Deployment Status

```yaml
- name: Create deployment
  uses: actions/github-script@v7
  with:
    script: |
      github.rest.repos.createDeployment({
        owner: context.repo.owner,
        repo: context.repo.repo,
        ref: context.sha,
        environment: 'production',
        auto_merge: false
      })
```

---

## Summary Checklist

Before deploying your CI/CD pipeline:

- [ ] All secrets configured in GitHub
- [ ] Ruby version matches `.ruby-version` file
- [ ] Node version is 20+ for Expo SDK 54
- [ ] Caching configured for npm, bundler, gradle, and pods
- [ ] Xcode version explicitly selected
- [ ] gradlew has execute permissions
- [ ] Bundle identifiers consistent across all files
- [ ] Pre-build validation script runs before builds
- [ ] Artifacts uploaded with retention policy
- [ ] Error notifications configured
- [ ] Branch protection rules enabled
- [ ] Cost optimization strategies applied

---

## Next Steps

1. **Test your workflow:**
   ```bash
   # Create a test branch
   git checkout -b test-ci
   git push origin test-ci
   ```

2. **Monitor first build:**
   - Check GitHub Actions tab
   - Review logs for any warnings
   - Verify artifacts uploaded correctly

3. **Optimize based on metrics:**
   - Track build times
   - Identify bottlenecks
   - Adjust caching strategy

4. **Document team workflow:**
   - How to trigger manual builds
   - How to add new secrets
   - Emergency rollback procedures

---

## Additional Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Fastlane Documentation](https://docs.fastlane.tools)
- [Expo Build Documentation](https://docs.expo.dev/build/introduction/)
- [React Native CI/CD Guide](https://reactnative.dev/docs/running-on-device)


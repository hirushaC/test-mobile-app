#!/bin/bash

# Pre-Build Validation Script
# Checks all requirements before running a build

set -e

ERRORS=0
WARNINGS=0

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Pre-Build Validation Script${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Function to print error
print_error() {
    echo -e "${RED}❌ ERROR: $1${NC}"
    ERRORS=$((ERRORS + 1))
}

# Function to print warning
print_warning() {
    echo -e "${YELLOW}⚠️  WARNING: $1${NC}"
    WARNINGS=$((WARNINGS + 1))
}

# Function to print success
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

# Function to print info
print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

echo "1. Checking Node.js and npm..."
if command -v node &> /dev/null; then
    NODE_VERSION=$(node --version)
    print_success "Node.js installed: $NODE_VERSION"
else
    print_error "Node.js not found. Please install Node.js"
fi

if command -v npm &> /dev/null; then
    NPM_VERSION=$(npm --version)
    print_success "npm installed: $NPM_VERSION"
else
    print_error "npm not found"
fi

echo ""
echo "2. Checking Ruby and Bundler..."
if command -v ruby &> /dev/null; then
    RUBY_VERSION=$(ruby --version)
    print_success "Ruby installed: $RUBY_VERSION"
else
    print_error "Ruby not found. Please install Ruby"
fi

if command -v bundle &> /dev/null; then
    BUNDLE_VERSION=$(bundle --version)
    print_success "Bundler installed: $BUNDLE_VERSION"
else
    print_error "Bundler not found. Run: gem install bundler"
fi

echo ""
echo "3. Checking project files..."

# Check package.json
if [ -f "package.json" ]; then
    print_success "package.json exists"
else
    print_error "package.json not found"
fi

# Check app.json
if [ -f "app.json" ]; then
    print_success "app.json exists"

    # Check bundle identifiers
    IOS_BUNDLE=$(grep -o '"bundleIdentifier":\s*"[^"]*"' app.json | cut -d'"' -f4)
    ANDROID_PACKAGE=$(grep -o '"package":\s*"[^"]*"' app.json | cut -d'"' -f4)

    if [ "$IOS_BUNDLE" == "com.testmobileapp" ]; then
        print_success "iOS bundle identifier: $IOS_BUNDLE"
    else
        print_warning "iOS bundle identifier is not com.testmobileapp: $IOS_BUNDLE"
    fi

    if [ "$ANDROID_PACKAGE" == "com.testmobileapp" ]; then
        print_success "Android package: $ANDROID_PACKAGE"
    else
        print_warning "Android package is not com.testmobileapp: $ANDROID_PACKAGE"
    fi
else
    print_error "app.json not found"
fi

# Check Gemfile
if [ -f "Gemfile" ]; then
    print_success "Gemfile exists"
else
    print_error "Gemfile not found"
fi

# Check fastlane directory
if [ -d "fastlane" ]; then
    print_success "fastlane directory exists"

    if [ -f "fastlane/Fastfile" ]; then
        print_success "Fastfile exists"
    else
        print_error "fastlane/Fastfile not found"
    fi

    if [ -f "fastlane/Appfile" ]; then
        print_success "Appfile exists"
    else
        print_error "fastlane/Appfile not found"
    fi
else
    print_error "fastlane directory not found"
fi

echo ""
echo "4. Checking Android setup..."

if [ -d "android" ]; then
    print_success "android directory exists"

    # Check gradlew
    if [ -f "android/gradlew" ]; then
        if [ -x "android/gradlew" ]; then
            print_success "android/gradlew is executable"
        else
            print_warning "android/gradlew is not executable. Run: chmod +x android/gradlew"
        fi
    else
        print_error "android/gradlew not found"
    fi

    # Check build.gradle
    if [ -f "android/app/build.gradle" ]; then
        print_success "android/app/build.gradle exists"

        # Check package name
        GRADLE_PACKAGE=$(grep 'namespace\s*"' android/app/build.gradle | cut -d'"' -f2)
        if [ "$GRADLE_PACKAGE" == "com.testmobileapp" ]; then
            print_success "Android namespace in build.gradle: $GRADLE_PACKAGE"
        else
            print_warning "Android namespace mismatch: $GRADLE_PACKAGE"
        fi
    else
        print_error "android/app/build.gradle not found"
    fi
else
    print_warning "android directory not found. Run: npm run prebuild"
fi

echo ""
echo "5. Checking iOS setup..."

if [ -d "ios" ]; then
    print_success "ios directory exists"

    # Check for xcodeproj
    if [ -d "ios/testmobileapp.xcodeproj" ]; then
        print_success "ios/testmobileapp.xcodeproj exists"
    else
        print_error "ios/testmobileapp.xcodeproj not found"
    fi

    # Check for workspace (created by CocoaPods)
    if [ -d "ios/testmobileapp.xcworkspace" ]; then
        print_success "ios/testmobileapp.xcworkspace exists"
    else
        print_warning "ios/testmobileapp.xcworkspace not found. Run: cd ios && pod install"
    fi

    # Check Podfile
    if [ -f "ios/Podfile" ]; then
        print_success "ios/Podfile exists"
    else
        print_error "ios/Podfile not found"
    fi

    # Check for Pods
    if [ -d "ios/Pods" ]; then
        print_success "ios/Pods directory exists"
    else
        print_warning "ios/Pods not found. Run: cd ios && pod install"
    fi
else
    print_warning "ios directory not found. Run: npm run prebuild"
fi

echo ""
echo "6. Checking environment variables (for CI builds)..."

check_env_var() {
    if [ -z "${!1}" ]; then
        print_warning "Environment variable not set: $1"
        return 1
    else
        print_success "Environment variable set: $1"
        return 0
    fi
}

# Android env vars
echo "  Android:"
check_env_var "ANDROID_KEYSTORE_BASE64" || check_env_var "ANDROID_KEYSTORE_PATH" || print_info "Set either ANDROID_KEYSTORE_BASE64 or ANDROID_KEYSTORE_PATH"
check_env_var "ANDROID_KEYSTORE_PASSWORD"
check_env_var "ANDROID_KEY_ALIAS"
check_env_var "ANDROID_KEY_PASSWORD"
check_env_var "GOOGLE_PLAY_SERVICE_KEY"

echo ""
echo "  iOS:"
check_env_var "APP_STORE_CONNECT_API_KEY_ID"
check_env_var "APP_STORE_CONNECT_ISSUER_ID"
check_env_var "APP_STORE_CONNECT_API_KEY"

echo ""
echo "7. Checking dependencies..."

# Check node_modules
if [ -d "node_modules" ]; then
    print_success "node_modules exists"
else
    print_warning "node_modules not found. Run: npm install"
fi

# Check if bundle install has been run
if [ -f "Gemfile.lock" ]; then
    print_success "Gemfile.lock exists"

    if bundle check &> /dev/null; then
        print_success "Ruby gems are installed"
    else
        print_warning "Ruby gems need to be installed. Run: bundle install"
    fi
else
    print_warning "Gemfile.lock not found. Run: bundle install"
fi

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Validation Summary${NC}"
echo -e "${BLUE}========================================${NC}"

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}✓ All checks passed! Ready to build.${NC}"
    exit 0
elif [ $ERRORS -eq 0 ]; then
    echo -e "${YELLOW}⚠️  $WARNINGS warning(s) found. Build may work but verify warnings.${NC}"
    exit 0
else
    echo -e "${RED}❌ $ERRORS error(s) and $WARNINGS warning(s) found.${NC}"
    echo -e "${RED}Please fix errors before building.${NC}"
    exit 1
fi

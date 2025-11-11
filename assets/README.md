# Assets Directory

This directory contains the required assets for your Expo React Native app.

## Required Assets

You need to create or add the following image files:

### 1. **icon.png**
- **Size:** 1024x1024 px
- **Purpose:** App icon for both iOS and Android
- **Format:** PNG with transparency
- **Requirements:** Square image, will be used as the base for all app icons

### 2. **splash.png**
- **Size:** 1284x2778 px (recommended) or 1242x2688 px
- **Purpose:** Splash screen displayed when app launches
- **Format:** PNG
- **Requirements:** Should work on various screen sizes, centered content recommended

### 3. **adaptive-icon.png**
- **Size:** 1024x1024 px
- **Purpose:** Android adaptive icon foreground
- **Format:** PNG with transparency
- **Requirements:** Keep important content in the safe area (central 66% of the image)

### 4. **favicon.png**
- **Size:** 48x48 px (or 32x32 px)
- **Purpose:** Web favicon when running as PWA
- **Format:** PNG
- **Requirements:** Small, recognizable version of your app icon

## How to Create Assets

### Option 1: Design Tools
Use design tools like:
- Figma (recommended - has Expo templates)
- Adobe Illustrator
- Sketch
- Canva

### Option 2: Online Generators
- [App Icon Generator](https://www.appicon.co/)
- [Expo Asset Generator](https://github.com/expo/expo-cli)

### Option 3: Use Expo's Asset Generator
Run this command to generate icons from a single source image:
```bash
npx @expo/image-utils generate-icons --icon path/to/your/icon.png
```

## Temporary Placeholder

For now, you can use a simple colored square as a placeholder until you have your final designs ready.

## Color Scheme

Current configuration uses:
- Background Color: #ffffff (white)
- Expo Default Purple: #4630EB (you can customize this in app.json)

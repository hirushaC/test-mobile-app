// Simple script to generate placeholder assets
// This creates basic SVG files that can be converted to PNG

const fs = require('fs');
const path = require('path');

const assetsDir = path.join(__dirname, 'assets');

// Function to create a simple SVG placeholder
function createSVG(width, height, text, bgColor = '#4630EB', textColor = '#FFFFFF') {
  return `<?xml version="1.0" encoding="UTF-8"?>
<svg width="${width}" height="${height}" xmlns="http://www.w3.org/2000/svg">
  <rect width="${width}" height="${height}" fill="${bgColor}"/>
  <text x="50%" y="50%" font-family="Arial, sans-serif" font-size="${Math.floor(width/15)}"
        fill="${textColor}" text-anchor="middle" dy=".3em">${text}</text>
</svg>`;
}

// Create SVG placeholders
const assets = [
  { name: 'icon.svg', width: 1024, height: 1024, text: 'App Icon' },
  { name: 'splash.svg', width: 1284, height: 2778, text: 'Splash Screen' },
  { name: 'adaptive-icon.svg', width: 1024, height: 1024, text: 'Android' },
  { name: 'favicon.svg', width: 48, height: 48, text: 'Web' }
];

console.log('Generating placeholder assets...\n');

assets.forEach(asset => {
  const svg = createSVG(asset.width, asset.height, asset.text);
  const filePath = path.join(assetsDir, asset.name);
  fs.writeFileSync(filePath, svg);
  console.log(`✓ Created ${asset.name} (${asset.width}x${asset.height})`);
});

console.log('\n✓ All placeholder SVG assets created!');
console.log('\nNote: Expo can use SVG files, or you can convert these to PNG using:');
console.log('  - Online tools like cloudconvert.com');
console.log('  - ImageMagick: magick convert icon.svg icon.png');
console.log('  - Or keep as SVG and update app.json to use .svg extension');

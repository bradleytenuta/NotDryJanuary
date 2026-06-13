const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

async function main() {
  const query = `
[out:json][timeout:120];
area["ISO3166-1"="GB"][admin_level=2]->.searchArea;
nwr["amenity"="pub"](area.searchArea);
out geom;
  `.trim();

  const url = 'https://overpass-api.de/api/interpreter';
  
  console.log('Fetching pub data from Overpass API (this might take up to a minute)...');
  
  const response = await fetch(url, {
    method: 'POST',
    body: 'data=' + encodeURIComponent(query),
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
      'User-Agent': 'NotDryJanuary-PubUpdater/1.0'
    }
  });

  if (!response.ok) {
    throw new Error(`Overpass API returned status: ${response.status} ${response.statusText}`);
  }

  console.log('Data fetched successfully. Saving raw OSM data to temp file...');
  const tempOsmFile = path.join(__dirname, 'temp_osm_raw.json');
  
  // To handle large responses and prevent memory bloat, we fetch text first
  const rawText = await response.text();
  
  // Basic validation that we received JSON and not an HTML error page
  try {
    JSON.parse(rawText);
  } catch (parseError) {
    throw new Error('Overpass API response was not valid JSON. Response starts with: ' + rawText.slice(0, 200));
  }
  
  fs.writeFileSync(tempOsmFile, rawText);

  const outGeoJsonFile = path.resolve(__dirname, '../assets/geojson/london-pubs.geojson');
  console.log(`Converting raw OSM data to GeoJSON format and writing to ${outGeoJsonFile}...`);

  try {
    // We execute osmtogeojson command line tool via npx.
    // We increase max buffer space just in case the output is very large.
    execSync(`npx osmtogeojson "${tempOsmFile}" > "${outGeoJsonFile}"`, {
      stdio: 'inherit',
      maxBuffer: 1024 * 1024 * 100 // 100 MB buffer
    });
    console.log('Conversion completed successfully.');
  } finally {
    console.log('Cleaning up temporary raw OSM file...');
    if (fs.existsSync(tempOsmFile)) {
      fs.unlinkSync(tempOsmFile);
    }
  }

  console.log('Done! Assets successfully updated.');
}

main().catch(err => {
  console.error('Error running update script:', err);
  process.exit(1);
});

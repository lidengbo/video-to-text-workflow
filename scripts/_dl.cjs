const https = require('https');
const http = require('http');
const fs = require('fs');
const { URL } = require('url');

const url = process.env.DL_URL;
const dest = process.env.DL_DEST;
const headers = { 'User-Agent': 'Mozilla/5.0' };

if (!url || !dest) {
  console.error('FAIL DL_URL and DL_DEST are required');
  process.exit(1);
}

function download(u, out, hdrs) {
  return new Promise((resolve, reject) => {
    const parsed = new URL(u);
    const client = parsed.protocol === 'https:' ? https : http;
    const request = client.request(parsed, { method: 'GET', headers: hdrs }, (response) => {
      if (response.statusCode >= 300 && response.statusCode < 400 && response.headers.location) {
        const next = response.headers.location.startsWith('http')
          ? response.headers.location
          : new URL(response.headers.location, parsed).toString();
        response.resume();
        return download(next, out, hdrs).then(resolve, reject);
      }
      if (response.statusCode >= 400) {
        response.resume();
        return reject(new Error(`HTTP ${response.statusCode}`));
      }
      const file = fs.createWriteStream(out);
      response.pipe(file);
      file.on('finish', () => file.close(() => resolve(fs.statSync(out).size)));
      file.on('error', reject);
    });
    request.setTimeout(60000, () => request.destroy(new Error('timeout')));
    request.on('error', reject);
    request.end();
  });
}

(async () => {
  try {
    const size = await download(url, dest, headers);
    console.log(`OK ${dest} ${size} bytes`);
  } catch (error) {
    console.error(`FAIL ${error.message}`);
    process.exit(1);
  }
})();

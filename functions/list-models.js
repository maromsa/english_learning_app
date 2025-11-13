#!/usr/bin/env node

/**
 * Script to list available Gemini models
 */

const http = require('https');

const GEMINI_API_KEY = process.env.GEMINI_API_KEY || process.argv[2];
if (!GEMINI_API_KEY) {
  console.error('❌ Error: GEMINI_API_KEY required');
  console.error('Usage: GEMINI_API_KEY=your_key node list-models.js');
  process.exit(1);
}

console.log('🔍 Fetching available Gemini models...\n');

// Try v1 API first
const options = {
  hostname: 'generativelanguage.googleapis.com',
  path: '/v1/models?key=' + GEMINI_API_KEY,
  method: 'GET',
  headers: {
    'Content-Type': 'application/json',
  },
};

const req = http.request(options, (res) => {
  let data = '';
  res.on('data', (chunk) => {
    data += chunk;
  });
  res.on('end', () => {
    try {
      const response = JSON.parse(data);
      if (response.models) {
        console.log('✅ Available models (v1 API):');
        console.log('='.repeat(60));
        response.models.forEach(model => {
          if (model.name && model.name.includes('flash')) {
            console.log(`  📌 ${model.name}`);
            console.log(`     Supported methods: ${model.supportedGenerationMethods?.join(', ') || 'N/A'}`);
            console.log('');
          }
        });
        console.log('\nAll flash models:');
        response.models
          .filter(m => m.name && m.name.includes('flash'))
          .forEach(model => {
            console.log(`  - ${model.name}`);
          });
      } else {
        console.error('❌ Unexpected response:', JSON.stringify(response, null, 2));
      }
    } catch (e) {
      console.error('❌ Error parsing response:', e.message);
      console.error('Response:', data);
    }
  });
});

req.on('error', (error) => {
  console.error('❌ Request error:', error.message);
});

req.end();


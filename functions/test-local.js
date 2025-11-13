#!/usr/bin/env node

/**
 * Test script for the geminiProxy Cloud Function running locally
 * Usage: GEMINI_API_KEY=your_key node test-local.js
 */

const http = require('http');

const GEMINI_API_KEY = process.env.GEMINI_API_KEY;
if (!GEMINI_API_KEY) {
  console.error('❌ Error: GEMINI_API_KEY environment variable is required');
  console.error('Usage: GEMINI_API_KEY=your_key node test-local.js');
  process.exit(1);
}

// Local emulator URL (default Firebase Functions emulator port)
const EMULATOR_URL = process.env.EMULATOR_URL || 'http://localhost:5001';
const PROJECT_ID = 'englishkidsapp-916be';
const FUNCTION_NAME = 'geminiProxy';
const FUNCTION_URL = `${EMULATOR_URL}/${PROJECT_ID}/us-central1/${FUNCTION_NAME}`;

console.log('🧪 Testing geminiProxy function locally...');
console.log(`📍 URL: ${FUNCTION_URL}`);
console.log('');

// Test 1: Text mode (the one that was failing)
async function testTextMode() {
  console.log('📝 Test 1: Text mode (Spark conversation)');
  
  const payload = {
    mode: 'text',
    prompt: 'Start a playful conversation with a young learner based on the supplied JSON context.\n\nContext:\n```\n{"topic":"space_mission","skillFocus":"confidence","energyLevel":"calm_magic","focusWords":["Apple","Banana","Orange","Strawberry","Pineapple","Grapes"]}\n```\n\nOutput JSON (no markdown fences) with keys:\n{\n  "opening": string,           // Spark\'s greeting and question (<= 70 Hebrew words, include 1-3 English vocabulary words inline)\n  "sparkTip": string,          // Short encouragement in Hebrew explaining what to try (<= 35 words)\n  "vocabularyHighlights": string[], // 1-3 English words that appeared, purely the words\n  "suggestedLearnerReplies": string[], // 2-3 short example replies the child could say (English with a few Hebrew helper words)\n  "miniChallenge": string      // Quick active idea (<= 25 words) encouraging gesture, drawing, or acting linked to the conversation\n}',
    system_instruction: 'You are Spark, an energetic AI mentor helping Hebrew-speaking kids aged 6-10 practise English conversation. You reply in warm, supportive Hebrew sentences sprinkled with short English phrases that match the lesson focus. Keep answers concise (max 70 Hebrew words) and highlight no more than three English words per turn. Always output minified JSON following the caller instructions. Never mention JSON, prompts, or Gemini.'
  };

  try {
    const response = await makeRequest(payload);
    console.log('✅ Success! Response:', JSON.stringify(response, null, 2));
    return true;
  } catch (error) {
    console.error('❌ Failed:', error.message);
    if (error.response) {
      console.error('Response body:', error.response);
    }
    return false;
  }
}

// Test 2: Simple text mode without system instruction
async function testSimpleText() {
  console.log('\n📝 Test 2: Simple text mode');
  
  const payload = {
    mode: 'text',
    prompt: 'Say hello in Hebrew and English'
  };

  try {
    const response = await makeRequest(payload);
    console.log('✅ Success! Response:', JSON.stringify(response, null, 2));
    return true;
  } catch (error) {
    console.error('❌ Failed:', error.message);
    if (error.response) {
      console.error('Response body:', error.response);
    }
    return false;
  }
}

// Helper function to make HTTP request
function makeRequest(payload) {
  return new Promise((resolve, reject) => {
    const url = new URL(FUNCTION_URL);
    const options = {
      hostname: url.hostname,
      port: url.port || (url.protocol === 'https:' ? 443 : 80),
      path: url.pathname,
      method: 'POST',
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
          const parsed = JSON.parse(data);
          if (res.statusCode >= 200 && res.statusCode < 300) {
            resolve(parsed);
          } else {
            const error = new Error(`HTTP ${res.statusCode}: ${parsed.error || data}`);
            error.response = parsed;
            reject(error);
          }
        } catch (e) {
          if (res.statusCode >= 200 && res.statusCode < 300) {
            resolve(data);
          } else {
            const error = new Error(`HTTP ${res.statusCode}: ${data}`);
            error.response = data;
            reject(error);
          }
        }
      });
    });

    req.on('error', (error) => {
      reject(error);
    });

    req.write(JSON.stringify(payload));
    req.end();
  });
}

// Run tests
async function runTests() {
  // Wait a bit for emulator to be ready
  await new Promise(resolve => setTimeout(resolve, 2000));
  
  const results = [];
  results.push(await testTextMode());
  results.push(await testSimpleText());
  
  console.log('\n' + '='.repeat(50));
  const passed = results.filter(r => r).length;
  const total = results.length;
  console.log(`\n📊 Results: ${passed}/${total} tests passed`);
  
  if (passed === total) {
    console.log('✅ All tests passed! The fix is working correctly.');
    process.exit(0);
  } else {
    console.log('❌ Some tests failed. Check the errors above.');
    process.exit(1);
  }
}

runTests().catch(error => {
  console.error('💥 Unexpected error:', error);
  process.exit(1);
});


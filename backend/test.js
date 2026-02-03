const axios = require('axios');

// Test configuration
const BASE_URL = 'http://localhost:3000'; // Change to your Render URL when deployed
const TEST_FCM_TOKEN = 'test_token_here'; // Replace with actual FCM token for testing

async function testAPI() {
  console.log('🧪 Testing Bus Tracking Backend API\n');

  try {
    // Test 1: Health check
    console.log('1️⃣ Testing health endpoint...');
    const healthResponse = await axios.get(`${BASE_URL}/health`);
    console.log('✅ Health check:', healthResponse.data);
    console.log('');

    // Test 2: Root endpoint
    console.log('2️⃣ Testing root endpoint...');
    const rootResponse = await axios.get(`${BASE_URL}/`);
    console.log('✅ Root endpoint:', rootResponse.data);
    console.log('');

    // Test 3: Valid location check
    console.log('3️⃣ Testing valid location check...');
    const validRequest = {
      lat: 10.081642,
      lng: 78.746657,
      fcmToken: TEST_FCM_TOKEN,
      placeName: 'Test School Gate'
    };
    
    const locationResponse = await axios.post(`${BASE_URL}/check-location`, validRequest);
    console.log('✅ Location check:', locationResponse.data);
    console.log('');

    // Test 4: Invalid request (missing fields)
    console.log('4️⃣ Testing invalid request...');
    try {
      await axios.post(`${BASE_URL}/check-location`, {
        lat: 'invalid',
        lng: 78.746657
      });
    } catch (error) {
      console.log('✅ Validation error (expected):', error.response.data);
    }
    console.log('');

    console.log('🎉 All tests completed!');

  } catch (error) {
    console.error('❌ Test failed:', error.message);
    if (error.response) {
      console.error('Response:', error.response.data);
    }
  }
}

// Run tests
testAPI();
const axios = require('axios');

const BASE_URL = 'https://farmy-c9hb-git-main-ahmed-alis-projects-588ffe47.vercel.app';

async function testEndpoint(method, endpoint, data = null) {
  try {
    console.log(`\n🔄 Testing ${method} ${endpoint}`);
    
    const config = {
      method: method.toLowerCase(),
      url: `${BASE_URL}${endpoint}`,
      headers: {
        'Content-Type': 'application/json'
      }
    };

    if (data) {
      config.data = data;
    }

    const response = await axios(config);
    
    console.log(`✅ Success (${response.status}):`);
    console.log('Response:', JSON.stringify(response.data, null, 2));
    
    return response.data;
  } catch (error) {
    if (error.response) {
      console.log(`❌ Error (${error.response.status}):`);
      console.log('Message:', error.response.data);
    } else {
      console.log(`❌ Network error:`, error.message);
    }
    return null;
  }
}

async function main() {
  console.log('🚀 Testing Farmy Backend API');
  console.log('=' .repeat(50));
  console.log(`📍 Base URL: ${BASE_URL}`);
  console.log('=' .repeat(50));

  // Test 1: Root endpoint (should work with GET)
  await testEndpoint('GET', '/');

  // Test 2: Signup endpoint (should work with POST)
  const signupData = {
    email: 'testmanager@farmy.com',
    password: 'test123',
    name: 'Test Manager',
    role: 'manager'
  };
  await testEndpoint('POST', '/api/signup', signupData);

  // Test 3: Login endpoint (should work with POST)
  const loginData = {
    email: 'testmanager@farmy.com',
    password: 'test123'
  };
  const loginResult = await testEndpoint('POST', '/api/login', loginData);

  // Test 4: Protected endpoint (if login was successful)
  if (loginResult && loginResult.token) {
    console.log('\n🔒 Testing protected endpoint with token...');
    try {
      const response = await axios.get(`${BASE_URL}/api/validate`, {
        headers: {
          'Authorization': `Bearer ${loginResult.token}`,
          'Content-Type': 'application/json'
        }
      });
      console.log('✅ Protected endpoint access successful:');
      console.log('Response:', JSON.stringify(response.data, null, 2));
    } catch (error) {
      console.log('❌ Protected endpoint failed:', error.response?.data || error.message);
    }
  }

  // Test 5: Wrong method (should give 405)
  console.log('\n🧪 Testing wrong HTTP method (expecting 405)...');
  await testEndpoint('GET', '/api/signup');

  console.log('\n🎉 API testing completed!');
}

main().catch(error => {
  console.error('💥 Test failed:', error.message);
});

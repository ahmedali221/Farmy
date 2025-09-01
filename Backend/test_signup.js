const axios = require('axios');

const BASE_URL = 'http://localhost:3000/api';

// Test data for signup
const testUsers = [
  {
    name: 'Admin User 1',
    data: {
      username: 'admin_user1',
      password: 'admin123456',
      role: 'manager'
    }
  },
  {
    name: 'Admin User 2',
    data: {
      username: 'admin_user2',
      password: 'admin123456',
      role: 'manager'
    }
  },
  {
    name: 'Employee User 1',
    data: {
      username: 'employee_user1',
      password: 'employee123456',
      role: 'employee'
    }
  },
  {
    name: 'Employee User 2',
    data: {
      username: 'employee_user2',
      password: 'employee123456',
      role: 'employee'
    }
  },
  {
    name: 'Default Employee (no role specified)',
    data: {
      username: 'default_employee',
      password: 'default123'
    }
  }
];

// Error test cases
const errorTestCases = [
  {
    name: 'Short Password',
    data: {
      username: 'short_pass_user',
      password: '123',
      role: 'employee'
    }
  },
  {
    name: 'Short Username',
    data: {
      username: 'ab',
      password: 'password123',
      role: 'employee'
    }
  },
  {
    name: 'Invalid Role',
    data: {
      username: 'invalid_role_user',
      password: 'password123',
      role: 'invalid_role'
    }
  },
  {
    name: 'Missing Username',
    data: {
      password: 'password123',
      role: 'employee'
    }
  },
  {
    name: 'Missing Password',
    data: {
      username: 'missing_pass_user',
      role: 'employee'
    }
  }
];

async function testSignup() {
  console.log('🚀 Testing Farmy Signup API\n');
  console.log('=' .repeat(50));

  // Test successful signups
  console.log('\n✅ Testing Successful Signups:\n');
  
  for (const user of testUsers) {
    try {
      console.log(`Testing: ${user.name}`);
      const response = await axios.post(`${BASE_URL}/signup`, user.data);
      
      console.log(`✅ Success! Status: ${response.status}`);
      console.log(`   User ID: ${response.data.user.id}`);
      console.log(`   Username: ${response.data.user.username}`);
      console.log(`   Role: ${response.data.user.role}`);
      console.log(`   Token: ${response.data.token.substring(0, 20)}...`);
      console.log('');
    } catch (error) {
      console.log(`❌ Failed: ${error.response?.data?.message || error.message}`);
      console.log('');
    }
  }

  // Test error cases
  console.log('\n❌ Testing Error Cases:\n');
  
  for (const testCase of errorTestCases) {
    try {
      console.log(`Testing: ${testCase.name}`);
      const response = await axios.post(`${BASE_URL}/signup`, testCase.data);
      console.log(`❌ Unexpected success! Should have failed.`);
      console.log('');
    } catch (error) {
      console.log(`✅ Expected error: ${error.response?.data?.message || error.message}`);
      console.log(`   Status: ${error.response?.status || 'Network Error'}`);
      console.log('');
    }
  }

  // Test duplicate username
  console.log('\n🔄 Testing Duplicate Username:\n');
  try {
    console.log('Creating first user...');
    await axios.post(`${BASE_URL}/signup`, {
      username: 'duplicate_test',
      password: 'password123',
      role: 'employee'
    });
    console.log('✅ First user created successfully');
    
    console.log('Attempting to create duplicate user...');
    await axios.post(`${BASE_URL}/signup`, {
      username: 'duplicate_test',
      password: 'password123',
      role: 'employee'
    });
    console.log('❌ Unexpected success! Should have failed.');
  } catch (error) {
    console.log(`✅ Expected error: ${error.response?.data?.message || error.message}`);
  }

  console.log('\n' + '=' .repeat(50));
  console.log('🎉 Signup testing completed!');
}

// Run the test
testSignup().catch(console.error);

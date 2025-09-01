# Farmy Signup API Testing Guide

## Overview
This guide provides comprehensive test data and instructions for testing the new signup endpoint in the Farmy backend API.

## New Signup Endpoint
- **URL**: `POST /api/signup`
- **Description**: Creates new users (admin/manager or employee)
- **Authentication**: Public endpoint (no token required)

## Quick Test Data

### 1. Admin/Manager Signup Examples

#### Example 1: Basic Admin Signup
```bash
curl -X POST http://localhost:3000/api/signup \
  -H "Content-Type: application/json" \
  -d '{
    "username": "admin_user",
    "password": "admin123456",
    "role": "manager"
  }'
```

#### Example 2: Another Admin
```bash
curl -X POST http://localhost:3000/api/signup \
  -H "Content-Type: application/json" \
  -d '{
    "username": "super_admin",
    "password": "super123456",
    "role": "manager"
  }'
```

### 2. Employee Signup Examples

#### Example 1: Basic Employee Signup
```bash
curl -X POST http://localhost:3000/api/signup \
  -H "Content-Type: application/json" \
  -d '{
    "username": "employee_user",
    "password": "employee123456",
    "role": "employee"
  }'
```

#### Example 2: Another Employee
```bash
curl -X POST http://localhost:3000/api/signup \
  -H "Content-Type: application/json" \
  -d '{
    "username": "worker1",
    "password": "worker123456",
    "role": "employee"
  }'
```

#### Example 3: Default Employee (no role specified)
```bash
curl -X POST http://localhost:3000/api/signup \
  -H "Content-Type: application/json" \
  -d '{
    "username": "default_employee",
    "password": "default123"
  }'
```

## Expected Responses

### Successful Signup Response (Status: 201)
```json
{
  "message": "User created successfully",
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "user": {
    "id": "64f8b2c1a3b4c5d6e7f8g9h0",
    "username": "admin_user",
    "role": "manager"
  }
}
```

### Error Responses

#### Username Already Exists (Status: 400)
```json
{
  "message": "Username already exists"
}
```

#### Validation Error (Status: 400)
```json
{
  "message": "Validation error details"
}
```

## Testing with Postman

### 1. Admin Signup Request
- **Method**: POST
- **URL**: `http://localhost:3000/api/signup`
- **Headers**: 
  - `Content-Type: application/json`
- **Body** (raw JSON):
```json
{
  "username": "admin_user",
  "password": "admin123456",
  "role": "manager"
}
```

### 2. Employee Signup Request
- **Method**: POST
- **URL**: `http://localhost:3000/api/signup`
- **Headers**: 
  - `Content-Type: application/json`
- **Body** (raw JSON):
```json
{
  "username": "employee_user",
  "password": "employee123456",
  "role": "employee"
}
```

## Automated Testing

### Running the Test Script
1. Make sure your server is running: `npm start`
2. Install axios if not already installed: `npm install axios`
3. Run the test script: `node test_signup.js`

The test script will:
- Test successful signups for both admin and employee roles
- Test error cases (validation errors)
- Test duplicate username handling
- Provide detailed output for each test case

## Validation Rules

### Username
- **Required**: Yes
- **Min Length**: 3 characters
- **Max Length**: 30 characters
- **Uniqueness**: Must be unique

### Password
- **Required**: Yes
- **Min Length**: 6 characters

### Role
- **Required**: No (defaults to 'employee')
- **Valid Values**: 'manager', 'employee'

## Error Test Cases

### 1. Short Password
```json
{
  "username": "short_pass_user",
  "password": "123",
  "role": "employee"
}
```
**Expected**: 400 Bad Request - Password too short

### 2. Short Username
```json
{
  "username": "ab",
  "password": "password123",
  "role": "employee"
}
```
**Expected**: 400 Bad Request - Username too short

### 3. Invalid Role
```json
{
  "username": "invalid_role_user",
  "password": "password123",
  "role": "invalid_role"
}
```
**Expected**: 400 Bad Request - Invalid role

### 4. Duplicate Username
```json
{
  "username": "admin",
  "password": "admin123456",
  "role": "manager"
}
```
**Expected**: 400 Bad Request - Username already exists

## Testing Workflow

1. **Start the server**: `npm start`
2. **Test successful signups** using the examples above
3. **Test error cases** to ensure proper validation
4. **Test login** with newly created users
5. **Verify role-based access** to protected endpoints

## Security Features

- **Password Hashing**: Passwords are automatically hashed using bcrypt
- **JWT Token**: Successful signup returns a JWT token for immediate authentication
- **Input Validation**: Comprehensive validation using Joi
- **Duplicate Prevention**: Username uniqueness enforced at database level

## Integration with Existing System

After signup, users can:
1. **Login** using the `/api/login` endpoint
2. **Access protected routes** using the returned JWT token
3. **Use role-based features** based on their assigned role (manager/employee)

## Troubleshooting

### Common Issues

1. **Server not running**: Make sure `npm start` is executed
2. **Database connection**: Ensure MongoDB is running and accessible
3. **Port conflicts**: Check if port 3000 is available
4. **JWT_SECRET**: Ensure the environment variable is set

### Debug Mode
Enable detailed logging by setting the log level in your environment:
```bash
export LOG_LEVEL=debug
```

## Next Steps

After successful signup testing:
1. Test login functionality with new users
2. Test role-based access to protected endpoints
3. Test the complete user workflow
4. Integrate with the frontend application

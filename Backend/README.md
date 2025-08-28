# Farmy Backend

This is the backend service for the Farmy application.

## Setup Instructions

### Prerequisites

- Node.js (v14 or higher)
- MongoDB (running locally or accessible via connection string)

### Installation

1. Clone the repository
2. Navigate to the Backend directory
3. Install dependencies:

```bash
npm install
```

### Environment Configuration

The application uses a `.env` file for configuration. A default file has been created with the following settings:

```
MONGO_URI=mongodb://localhost:27017/farmy
PORT=3000
JWT_SECRET=farmy_secret_key_for_development_only
NODE_ENV=development
```

Modify these values as needed for your environment.

### Seeding Data

To populate the database with sample users (including an admin account):

```bash
npm run seed
```

This will create the following users:
- admin (role: manager, password: admin123)
- employee1 (role: employee, password: employee123)
- manager1 (role: manager, password: manager123)

### Running the Application

Start the server in development mode with hot reloading:

```bash
npm run dev
```

Or start in production mode:

```bash
npm start
```

The server will run on port 3000 by default (or the port specified in your .env file).

## API Documentation

API endpoints are documented in the Postman collection included in the project root (`postman_collection.json`).

## Project Structure

- `/src` - Source code
  - `/customers` - Customer-related functionality
  - `/deliveries` - Delivery management
  - `/employees` - Employee management
  - `/finances` - Financial operations
  - `/managers` - Manager operations and authentication
  - `/middleware` - Express middleware
  - `/orders` - Order processing
  - `/utils` - Utility functions and scripts
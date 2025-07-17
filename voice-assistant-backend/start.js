#!/usr/bin/env node

const { execSync } = require('child_process');

console.log('Starting Voice Assistant Backend...');
console.log('Environment:', process.env.NODE_ENV);
console.log('Port:', process.env.PORT || 3000);

// Attempt database migration
try {
  console.log('Running database migrations...');
  execSync('npx prisma migrate deploy', { stdio: 'inherit' });
  console.log('Database migrations completed successfully');
} catch (error) {
  console.error('Database migration failed:', error.message);
  console.log('Continuing with startup despite migration failure...');
  // Don't exit on migration failure - the database might already be migrated
}

// Start the application
try {
  console.log('Starting application server...');
  require('./src/app.js');
} catch (error) {
  console.error('Failed to start application:', error);
  process.exit(1);
}
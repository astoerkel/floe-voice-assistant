const Redis = require('ioredis');
const logger = require('../utils/logger');

let redis = null;
let isRedisAvailable = false;

// Mock Redis client for when Redis is not available
const mockRedisClient = {
  get: async () => null,
  set: async () => 'OK',
  setex: async () => 'OK',
  del: async () => 1,
  exists: async () => 0,
  expire: async () => 1,
  ttl: async () => -1,
  keys: async () => [],
  flushall: async () => 'OK',
  connect: async () => { logger.warn('Mock Redis client - no actual connection'); },
  disconnect: async () => { logger.warn('Mock Redis client - no actual disconnection'); }
};

// Check if Redis should be used - disable if URL contains localhost or railway internal
const shouldUseRedis = process.env.REDIS_URL && 
  !process.env.REDIS_URL.includes('localhost') && 
  !process.env.REDIS_URL.includes('railway.internal') &&
  !process.env.DISABLE_REDIS;

if (shouldUseRedis) {
  redis = new Redis(process.env.REDIS_URL, {
    maxRetriesPerRequest: 3,
    retryDelayOnFailover: 100,
    enableReadyCheck: false,
    lazyConnect: true,
    reconnectOnError: (err) => {
      logger.error('Redis connection error:', err);
      isRedisAvailable = false;
      return false; // Don't retry indefinitely
    }
  });
} else {
  logger.warn('Redis disabled or not available - using fallback mode');
  redis = mockRedisClient;
}

const connectRedis = async () => {
  if (!shouldUseRedis) {
    logger.warn('Redis disabled or not available, using fallback mode');
    redis = mockRedisClient;
    isRedisAvailable = false;
    return;
  }
  
  try {
    await redis.connect();
    isRedisAvailable = true;
    logger.info('Connected to Redis successfully');
    
    redis.on('error', (err) => {
      logger.error('Redis error:', err);
      isRedisAvailable = false;
    });
    
    redis.on('reconnecting', () => {
      logger.info('Redis reconnecting...');
      isRedisAvailable = false;
    });
    
    redis.on('ready', () => {
      logger.info('Redis ready');
      isRedisAvailable = true;
    });
    
  } catch (error) {
    logger.error('Failed to connect to Redis:', error);
    logger.warn('Falling back to database-only mode');
    isRedisAvailable = false;
    redis = mockRedisClient;
  }
};

const disconnectRedis = async () => {
  try {
    await redis.disconnect();
    logger.info('Disconnected from Redis');
  } catch (error) {
    logger.error('Error disconnecting from Redis:', error);
  }
};

module.exports = {
  redis,
  connectRedis,
  disconnectRedis,
  isRedisAvailable: () => isRedisAvailable
};
import { app } from './app.js';
import { env } from './config/env.js';
import { logger } from './config/logger.js';
import { checkSupabaseHealth } from './config/supabase.js';
import { redis, checkRedisHealth } from './config/redis.js';

const startServer = async () => {
  try {
    logger.info('🔍 Running startup environment & infrastructure checks...');

    // Asynchronous infrastructure connectivity checks (non-blocking for resilient start)
    const [supabaseReady, redisReady] = await Promise.all([
      checkSupabaseHealth(),
      checkRedisHealth(),
    ]);

    if (!supabaseReady) {
      logger.warn('⚠️ Supabase database check returned non-ready during startup. API will proceed with retry policies.');
    } else {
      logger.info('✅ Supabase connection verified.');
    }

    if (!redisReady) {
      logger.warn('⚠️ Redis check returned non-ready during startup. API will proceed with memory fallbacks.');
    } else {
      logger.info('✅ Redis connection verified.');
    }

    // Start HTTP Server
    const server = app.listen(env.PORT, () => {
      logger.info(
        `🚀 ZankoAI DigitalOcean Backend is running on port ${env.PORT} in [${env.NODE_ENV}] mode`
      );
      logger.info(`🔗 Liveness Probe:   GET http://localhost:${env.PORT}/api/health`);
      logger.info(`🔗 Readiness Probe:  GET http://localhost:${env.PORT}/api/ready`);
    });

    // ─── Graceful Shutdown Handler ───
    const handleShutdown = (signal: string) => {
      logger.info(`🛑 Received ${signal}. Starting graceful shutdown...`);

      // 1. Stop taking new requests
      server.close(async () => {
        logger.info('✅ HTTP server closed. Closing external connections...');

        try {
          // 2. Disconnect Redis
          await redis.quit();
          logger.info('✅ Redis connection closed.');
        } catch (err) {
          logger.error('Error closing Redis connection:', err);
        }

        logger.info('👋 Graceful shutdown complete. Exiting.');
        process.exit(0);
      });

      // Force exit after 10 seconds if lingering requests do not finish
      setTimeout(() => {
        logger.error('❌ Forceful shutdown timeout exceeded. Exiting immediately.');
        process.exit(1);
      }, 10000).unref();
    };

    process.on('SIGTERM', () => handleShutdown('SIGTERM'));
    process.on('SIGINT', () => handleShutdown('SIGINT'));
  } catch (error) {
    logger.error('💥 Fatal error during server startup:', error);
    process.exit(1);
  }
};

startServer();

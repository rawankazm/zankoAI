import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import { env } from './config/env.js';
import { logger } from './config/logger.js';
import { errorHandler } from './middleware/error_handler.js';
import { aiRoutes } from './modules/ai/ai.routes.js';
import { paymentRoutes } from './modules/payments/payment.routes.js';
import { academicRoutes } from './modules/academic/academic.routes.js';

const app = express();

// Security Middlewares
app.use(helmet());
app.use(
  cors({
    origin: env.CORS_ORIGIN.split(','),
    credentials: true,
  })
);
app.use(express.json({ limit: '25mb' }));
app.use(express.urlencoded({ extended: true, limit: '25mb' }));

// Health Check
app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    service: 'ZankoAI DigitalOcean Backend API',
    environment: env.NODE_ENV,
    timestamp: new Date().toISOString(),
  });
});

// Mount Routes
app.use(`${env.API_PREFIX}/ai`, aiRoutes);
app.use(`${env.API_PREFIX}/payments`, paymentRoutes);
app.use(`${env.API_PREFIX}/academic`, academicRoutes);

// Global Error Handler
app.use(errorHandler);

const server = app.listen(env.PORT, () => {
  logger.info(`🚀 ZankoAI Backend Server is running on port ${env.PORT} (${env.NODE_ENV})`);
});

// Graceful Shutdown
const shutdown = () => {
  logger.info('Shutting down server gracefully...');
  server.close(() => {
    logger.info('Server closed.');
    process.exit(0);
  });
};

process.on('SIGTERM', shutdown);
process.on('SIGINT', shutdown);

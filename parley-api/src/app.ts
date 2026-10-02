import express, { Application } from 'express';
import cors from 'cors';
import helmet from 'helmet';
import morgan from 'morgan';
import { config } from './config/env';
import routes from './routes';
import { errorHandler } from './middleware/error.middleware';
import { notFoundHandler } from './middleware/notFound.middleware';
import { transformResponse } from './middleware/transform.middleware';
import { correlationId } from './middleware/correlation.middleware';
import { stream } from './utils/logger';

const app: Application = express();

// Correlation ID middleware (must be first to ensure all logs have correlation ID)
app.use(correlationId);

// Security middleware
app.use(helmet());

// CORS with dynamic origin validation
const allowedOrigins = [
  'http://localhost:5173',
  'http://localhost:3000',
  config.frontendUrl,
].filter(Boolean) as string[];

app.use(cors({
  origin: (origin, callback) => {
    // Allow requests with no origin (server-to-server, curl, etc.)
    if (!origin) return callback(null, true);
    // Allow explicitly listed origins
    if (allowedOrigins.includes(origin)) return callback(null, true);

    callback(new Error(`Origin ${origin} not allowed by CORS`));
  },
  credentials: true,
  allowedHeaders: ['Content-Type', 'Authorization', 'Cookie'],
}));

// Response transform middleware (wraps responses in consistent format).
// Before body parsing, so a parser error (413, bad JSON) is wrapped like the rest.
app.use(transformResponse);

// Body parsing middleware
// 1 MB: a full 500-row dictionary push is ~300 kB, past the 100 kB default.
app.use(express.json({ limit: '1mb' }));
app.use(express.urlencoded({ extended: true }));

// Logging middleware - integrated with Winston
if (config.nodeEnv === 'development') {
  app.use(morgan('dev', { stream }));
} else {
  app.use(morgan('combined', { stream }));
}

// API routes
app.use('/api', routes);

// Root route
app.get('/', (req, res) => {
  res.json({
    message: 'Parley sync API',
    version: '1.0.0',
    endpoints: {
      health: '/api/health',
      auth: '/api/auth/token',
      me: '/api/me',
      dictionary: '/api/dictionary',
      settings: '/api/settings',
      history: '/api/history',
      tasks: '/api/tasks',
    }
  });
});

// 404 handler
app.use(notFoundHandler);

// Error handler (must be last)
app.use(errorHandler);

export default app;

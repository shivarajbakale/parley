import winston from 'winston';
import DailyRotateFile from 'winston-daily-rotate-file';
import { config } from '../config/env';

interface LogInfo {
  level: string;
  message: string;
  timestamp?: string;
  correlationId?: string;
  stack?: string;
  [key: string | symbol]: unknown;
}

// Define log levels
const levels = {
  error: 0,
  warn: 1,
  info: 2,
  http: 3,
  debug: 4
};

// Define log colors
const colors = {
  error: 'red',
  warn: 'yellow',
  info: 'green',
  http: 'magenta',
  debug: 'white'
};

winston.addColors(colors);

// Define log format
const logFormat = winston.format.combine(
  winston.format.timestamp({ format: 'YYYY-MM-DD HH:mm:ss' }),
  winston.format.errors({ stack: true }),
  winston.format.splat(),
  winston.format.json()
);

// Console format for development
const consoleFormat = winston.format.combine(
  winston.format.colorize({ all: true }),
  winston.format.timestamp({ format: 'YYYY-MM-DD HH:mm:ss' }),
  winston.format.printf((info: winston.Logform.TransformableInfo) => {
    const logInfo = info as unknown as LogInfo;
    const { timestamp, level, message, correlationId, stack } = logInfo;
    return `${timestamp} [${level}]${correlationId ? ` [${correlationId}]` : ''}: ${message}${stack ? `\n${stack}` : ''}`;
  })
);

// Determine log level based on environment
const level = (): string => {
  const env = config.nodeEnv || 'development';
  const isDevelopment = env === 'development';
  return isDevelopment ? 'debug' : 'warn';
};

// Define transports
const transports: winston.transport[] = [];

// Console transport (always enabled)
transports.push(
  new winston.transports.Console({
    format: config.nodeEnv === 'development' ? consoleFormat : logFormat
  })
);

// File transports (only in production)
if (config.nodeEnv === 'production') {
  // Error log file with rotation
  transports.push(
    new DailyRotateFile({
      filename: 'logs/error-%DATE%.log',
      datePattern: 'YYYY-MM-DD',
      level: 'error',
      maxFiles: '14d',
      maxSize: '20m',
      format: logFormat
    })
  );

  // Combined log file with rotation
  transports.push(
    new DailyRotateFile({
      filename: 'logs/combined-%DATE%.log',
      datePattern: 'YYYY-MM-DD',
      maxFiles: '14d',
      maxSize: '20m',
      format: logFormat
    })
  );
}

// Create the logger instance
const logger = winston.createLogger({
  level: level(),
  levels,
  format: logFormat,
  transports,
  // Don't exit on handled exceptions
  exitOnError: false
});

// Create a stream object for Morgan HTTP logger
export const stream = {
  write: (message: string) => {
    logger.http(message.trim());
  }
};

// Helper class to maintain the same interface as before
class Logger {
  private static sanitizeData(data: unknown): unknown {
    if (!data) return data;

    // List of sensitive keys to redact
    const sensitiveKeys = [
      'password',
      'token',
      'secret',
      'apiKey',
      'api_key',
      'authorization',
      'credit_card',
      'ssn'
    ];

    if (typeof data === 'object' && data !== null) {
      if (Array.isArray(data)) {
        return data.map(item => Logger.sanitizeData(item));
      }

      const sanitized: Record<string, unknown> = { ...data };

      for (const key in sanitized) {
        const lowerKey = key.toLowerCase();
        if (sensitiveKeys.some(sensitive => lowerKey.includes(sensitive))) {
          sanitized[key] = '***REDACTED***';
        } else if (typeof sanitized[key] === 'object') {
          sanitized[key] = Logger.sanitizeData(sanitized[key]);
        }
      }

      return sanitized;
    }

    return data;
  }

  info(message: string, ...args: unknown[]): void {
    const sanitizedArgs = args.map(arg => Logger.sanitizeData(arg));
    logger.info(message, ...sanitizedArgs);
  }

  error(message: string, ...args: unknown[]): void {
    const sanitizedArgs = args.map(arg => Logger.sanitizeData(arg));
    logger.error(message, ...sanitizedArgs);
  }

  warn(message: string, ...args: unknown[]): void {
    const sanitizedArgs = args.map(arg => Logger.sanitizeData(arg));
    logger.warn(message, ...sanitizedArgs);
  }

  debug(message: string, ...args: unknown[]): void {
    const sanitizedArgs = args.map(arg => Logger.sanitizeData(arg));
    logger.debug(message, ...sanitizedArgs);
  }

  http(message: string, ...args: unknown[]): void {
    const sanitizedArgs = args.map(arg => Logger.sanitizeData(arg));
    logger.http(message, ...sanitizedArgs);
  }
}

export default new Logger();
export { logger };

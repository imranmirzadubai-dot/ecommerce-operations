export type LogLevel = 'debug' | 'info' | 'warn' | 'error';

export type LogContext = Record<string, unknown>;

const REDACTED_KEYS = new Set([
  'access_token',
  'accessToken',
  'refresh_token',
  'refreshToken',
  'authorization',
  'password',
  'token',
  'service_role',
  'serviceRole',
]);

function sanitizeValue(value: unknown): unknown {
  if (Array.isArray(value)) return value.map(sanitizeValue);
  if (!value || typeof value !== 'object') return value;

  const result: Record<string, unknown> = {};
  for (const [key, nested] of Object.entries(value)) {
    result[key] = REDACTED_KEYS.has(key) ? '[REDACTED]' : sanitizeValue(nested);
  }
  return result;
}

export function createLogEntry(
  level: LogLevel,
  message: string,
  context: LogContext = {},
  now: Date = new Date(),
): Record<string, unknown> {
  return {
    timestamp: now.toISOString(),
    level,
    message,
    context: sanitizeValue(context),
  };
}

function emit(level: LogLevel, message: string, context?: LogContext): void {
  const entry = createLogEntry(level, message, context);
  const line = JSON.stringify(entry);

  if (level === 'error') console.error(line);
  else if (level === 'warn') console.warn(line);
  else console.log(line);
}

export const logger = {
  debug(message: string, context?: LogContext): void {
    emit('debug', message, context);
  },
  info(message: string, context?: LogContext): void {
    emit('info', message, context);
  },
  warn(message: string, context?: LogContext): void {
    emit('warn', message, context);
  },
  error(message: string, context?: LogContext): void {
    emit('error', message, context);
  },
};

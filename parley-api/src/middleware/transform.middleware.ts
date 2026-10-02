import { Request, Response, NextFunction } from 'express';

export interface TransformedResponse<T> {
  data: T;
  meta: {
    timestamp: string;
    statusCode: number;
  };
}

// Middleware to transform all responses to match NestJS format
export const transformResponse = (req: Request, res: Response, next: NextFunction): void => {
  // Store the original json method
  const originalJson = res.json.bind(res);

  // Override res.json to wrap the response
  res.json = function (body: any): Response {
    // If already transformed (has data and meta), don't transform again
    if (body && typeof body === 'object' && 'data' in body && 'meta' in body) {
      return originalJson(body);
    }

    // Transform the response
    const transformed: TransformedResponse<any> = {
      data: body,
      meta: {
        timestamp: new Date().toISOString(),
        statusCode: res.statusCode
      }
    };

    return originalJson(transformed);
  };

  next();
};

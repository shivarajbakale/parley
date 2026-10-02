import { Request, Response, NextFunction } from 'express';
import { AnyZodObject, ZodError } from 'zod';
import { AppError } from './error.middleware';

export const validate = (schema: AnyZodObject) => {
  return async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      await schema.parseAsync(req.body);
      next();
    } catch (error) {
      if (error instanceof ZodError) {
        const errorMessages = error.errors
          .map(err => `${err.path.join('.')}: ${err.message}`)
          .join(', ');
        next(new AppError(errorMessages, 400));
      } else {
        next(new AppError('Validation failed', 400));
      }
    }
  };
};

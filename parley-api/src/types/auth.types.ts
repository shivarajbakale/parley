import { z } from 'zod';

export const tokenRequestSchema = z.object({
  email: z.string().email(),
  label: z.string().max(80).optional(),
});
export type TokenRequestDto = z.infer<typeof tokenRequestSchema>;

declare global {
  // eslint-disable-next-line @typescript-eslint/no-namespace
  namespace Express {
    interface Request { userId?: string }
  }
}

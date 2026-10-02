# Building a Feature

The canonical recipe for adding a new resource (a CRUD endpoint group). Follow
the steps in order; each maps to one layer in [ARCHITECTURE.md](ARCHITECTURE.md).
[EXAMPLE_FEATURE.md](EXAMPLE_FEATURE.md) runs this end-to-end for a `Note`.

Replace `Thing`/`things` with your resource name throughout.

## 1. Model — `prisma/schema.prisma`

```prisma
model Thing {
  id        String   @id @default(uuid())
  name      String
  done      Boolean  @default(false)
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt

  @@map("things")
}
```

Apply it and regenerate the client:

```bash
make db        # prisma db push
make generate  # prisma generate
```

## 2. Types — `src/types/thing.types.ts`

```ts
import { z } from 'zod';

export const createThingSchema = z.object({
  name: z.string().min(1, 'Name is required'),
  done: z.boolean().optional(),
});

export const updateThingSchema = createThingSchema.partial();

export type CreateThingDto = z.infer<typeof createThingSchema>;
export type UpdateThingDto = z.infer<typeof updateThingSchema>;
```

## 3. Service — `src/services/thing.service.ts`

All business logic + Prisma access live here. Throw `AppError` for expected
failures. (`AppError` is the exported name of the error class — see
`src/middleware/error.middleware.ts`.)

```ts
import { AppError } from '../middleware/error.middleware';
import prisma from '../config/database';
import { CreateThingDto, UpdateThingDto } from '../types/thing.types';

export const create = (data: CreateThingDto) => prisma.thing.create({ data });

export const findAll = () => prisma.thing.findMany({ orderBy: { createdAt: 'desc' } });

export const findOne = async (id: string) => {
  const thing = await prisma.thing.findUnique({ where: { id } });
  if (!thing) throw new AppError('Thing not found', 404);
  return thing;
};

export const update = async (id: string, data: UpdateThingDto) => {
  await findOne(id);
  return prisma.thing.update({ where: { id }, data });
};

export const remove = async (id: string) => {
  await findOne(id);
  await prisma.thing.delete({ where: { id } });
};
```

## 4. Controller — `src/controllers/thing.controller.ts`

Thin. Wrap each handler in `asyncHandler`. Return raw data (the transform
middleware adds the envelope) and set the right status code.

```ts
import { Request, Response } from 'express';
import { asyncHandler } from '../middleware/error.middleware';
import * as thingService from '../services/thing.service';

export const create = asyncHandler(async (req: Request, res: Response) => {
  res.status(201).json(await thingService.create(req.body));
});

export const findAll = asyncHandler(async (_req: Request, res: Response) => {
  res.status(200).json(await thingService.findAll());
});

export const findOne = asyncHandler(async (req: Request, res: Response) => {
  res.status(200).json(await thingService.findOne(req.params.id));
});

export const update = asyncHandler(async (req: Request, res: Response) => {
  res.status(200).json(await thingService.update(req.params.id, req.body));
});

export const remove = asyncHandler(async (req: Request, res: Response) => {
  await thingService.remove(req.params.id);
  res.status(204).send();
});
```

> Note: return raw data (`res.json(data)`), not `{ status, data }`. Wrapping it
> yourself produces a double-nested response once the transform middleware runs.

## 5. Routes — `src/routes/thing.routes.ts`

```ts
import { Router } from 'express';
import * as controller from '../controllers/thing.controller';
import { validate } from '../middleware/validate.middleware';
import { createThingSchema, updateThingSchema } from '../types/thing.types';

const router = Router();
router.post('/', validate(createThingSchema), controller.create);
router.get('/', controller.findAll);
router.get('/:id', controller.findOne);
router.put('/:id', validate(updateThingSchema), controller.update);
router.delete('/:id', controller.remove);
export default router;
```

## 6. Register — `src/routes/index.ts`

```ts
import thingRoutes from './thing.routes';
router.use('/things', thingRoutes);
```

## 7. Test + evidence

- **Level 2** (no DB): a `validate` test in `test/thing.validation.test.ts`
  asserting a bad body returns 400.
- **Level 3** (DB): extend or add `test/thing.e2e.test.ts` (gated by
  `RUN_DB_TESTS`) exercising create → read → update → delete.

Then update `feature_list.json`: set the feature `passing` with the commands you
ran and the test names as `evidence`. Run `make verify` before you call it done.

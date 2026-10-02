# Worked Example: a `Note` resource

This runs the [FEATURES.md](FEATURES.md) recipe end-to-end so you can see the
full loop — model → types → service → controller → routes → register → verify —
with the exact commands and the evidence you'd record. Delete this resource (or
keep it) once you've used it as a reference.

**Goal:** `GET/POST/GET:id/PUT:id/DELETE:id /api/notes`, a note being
`{ id, title, body, createdAt, updatedAt }`, with validation and an e2e test.

---

## 1. Model

Add to `prisma/schema.prisma`:

```prisma
model Note {
  id        String   @id @default(uuid())
  title     String
  body      String?
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt

  @@map("notes")
}
```

```bash
make db && make generate
```

## 2. Types — `src/types/note.types.ts`

```ts
import { z } from 'zod';

export const createNoteSchema = z.object({
  title: z.string().min(1, 'Title is required'),
  body: z.string().optional(),
});
export const updateNoteSchema = createNoteSchema.partial();

export type CreateNoteDto = z.infer<typeof createNoteSchema>;
export type UpdateNoteDto = z.infer<typeof updateNoteSchema>;
```

## 3. Service — `src/services/note.service.ts`

```ts
import { AppError } from '../middleware/error.middleware';
import prisma from '../config/database';
import { CreateNoteDto, UpdateNoteDto } from '../types/note.types';

export const create = (data: CreateNoteDto) => prisma.note.create({ data });
export const findAll = () => prisma.note.findMany({ orderBy: { createdAt: 'desc' } });

export const findOne = async (id: string) => {
  const note = await prisma.note.findUnique({ where: { id } });
  if (!note) throw new AppError('Note not found', 404);
  return note;
};

export const update = async (id: string, data: UpdateNoteDto) => {
  await findOne(id);
  return prisma.note.update({ where: { id }, data });
};

export const remove = async (id: string) => {
  await findOne(id);
  await prisma.note.delete({ where: { id } });
};
```

## 4. Controller — `src/controllers/note.controller.ts`

```ts
import { Request, Response } from 'express';
import { asyncHandler } from '../middleware/error.middleware';
import * as noteService from '../services/note.service';

export const create = asyncHandler(async (req: Request, res: Response) => {
  res.status(201).json(await noteService.create(req.body));
});
export const findAll = asyncHandler(async (_req: Request, res: Response) => {
  res.status(200).json(await noteService.findAll());
});
export const findOne = asyncHandler(async (req: Request, res: Response) => {
  res.status(200).json(await noteService.findOne(req.params.id));
});
export const update = asyncHandler(async (req: Request, res: Response) => {
  res.status(200).json(await noteService.update(req.params.id, req.body));
});
export const remove = asyncHandler(async (req: Request, res: Response) => {
  await noteService.remove(req.params.id);
  res.status(204).send();
});
```

## 5. Routes — `src/routes/note.routes.ts`

```ts
import { Router } from 'express';
import * as controller from '../controllers/note.controller';
import { validate } from '../middleware/validate.middleware';
import { createNoteSchema, updateNoteSchema } from '../types/note.types';

const router = Router();
router.post('/', validate(createNoteSchema), controller.create);
router.get('/', controller.findAll);
router.get('/:id', controller.findOne);
router.put('/:id', validate(updateNoteSchema), controller.update);
router.delete('/:id', controller.remove);
export default router;
```

## 6. Register — `src/routes/index.ts`

```ts
import noteRoutes from './note.routes';
// ...
router.use('/notes', noteRoutes);
```

## 7. Test — `test/note.e2e.test.ts`

```ts
import { describe, it, expect } from 'vitest';
import request from 'supertest';
import app from '../src/app';

const dbDescribe = process.env.RUN_DB_TESTS ? describe : describe.skip;

dbDescribe('note CRUD (e2e)', () => {
  it('creates and reads a note', async () => {
    const created = await request(app)
      .post('/api/notes')
      .send({ title: 'first note', body: 'hello' });
    expect(created.status).toBe(201);
    const id = created.body.data.id;

    const fetched = await request(app).get(`/api/notes/${id}`);
    expect(fetched.status).toBe(200);
    expect(fetched.body.data.title).toBe('first note');
  });
});
```

Also add a Level-2 validation test (`test/note.validation.test.ts`) asserting
`POST /api/notes` with `{}` returns 400.

## 8. Verify + record

```bash
make verify    # db push + type-check + lint + test + RUN_DB_TESTS e2e
```

Then in `feature_list.json` set the feature `passing` with:

```json
"verification": ["make verify"],
"evidence": [
  "test/note.e2e.test.ts — create + read",
  "test/note.validation.test.ts — empty body -> 400"
]
```

That's the whole loop. A fresh session can now see exactly what exists, how it's
verified, and where the evidence lives — without reading the diff.

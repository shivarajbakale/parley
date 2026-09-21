---
name: add-api-endpoint
description: Add a single API call (service method + matching MSW mock + query/mutation hook) so the frontend stays runnable with no backend. Use when the user wants one new endpoint or action on an existing resource (e.g. "archive a project", "fetch stats", "invite a member").
---

# add-api-endpoint — one endpoint, mock included

Keep the three layers in lockstep so the app runs standalone (MSW) and against a
real API without code changes. Reference: the Projects slice.

## The three edits

1. **Service method** — add to the resource's service (e.g.
   `src/api/services/projectService.ts`). Use `apiClient` + `extractData`; return
   the unwrapped domain type. Example:
   ```ts
   async archive(id: string): Promise<Project> {
     const res = await apiClient.post<ApiResponse<Project>>(`/projects/${id}/archive`, {});
     return extractData(res);
   }
   ```
2. **MSW handler** — add a matching handler in the resource's handler file (e.g.
   `src/mocks/handlers/projectHandlers.ts`) so the endpoint works with no backend.
   Return the `{ success, data }` envelope with the right status.
3. **Query/mutation hook** — add to the resource's hooks (e.g.
   `src/hooks/useProjects.ts`). Mutations invalidate via the `xKeys` factory and
   raise a `sonner` toast on success/error, matching the existing hooks.

## Rules

- Endpoint paths are relative and start with `/api` implicitly (axios `baseURL`
  is `/api`; MSW handlers match `/api/...`).
- Reuse the `ApiResponse<T>` envelope from `src/api/types/api.types.ts`.
- Never call the service directly from a component — always go through a hook.

## Verify

`npm run type-check`; add/extend a test in `src/test/` that exercises the new
handler; drive it in the UI with `npm run dev`.

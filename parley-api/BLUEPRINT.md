# API Blueprint

> **For the agent:** if this file is still in stub form (no `One-liner`
> filled in, no `Approved` checkbox ticked), produce a real blueprint from
> the user's brief BEFORE touching `feature_list.json`. Protocol:
> [docs/BLUEPRINT.md](docs/BLUEPRINT.md). Do not start implementation until
> the user ticks **Approved**.
>
> **For the user:** describe the API you want (one paragraph is fine). The
> agent fills in the sections below, you review, you tick **Approved**, then
> features get queued. Change anything you like first — this is a 5-minute
> alignment doc, not a contract.

---

**One-liner:** _(filled by the agent from your brief)_

**Status:**
- [ ] drafted
- [ ] approved

**Last updated:** _(YYYY-MM-DD)_

## Resources & endpoints

| # | Resource | Method + path | Auth | Purpose |
|---|----------|---------------|------|---------|
| 1 | _name_   | `GET /api/…`  | none / token | one-sentence purpose |
| 2 | _name_   | `POST /api/…` | none / token | one-sentence purpose |

> Follow the boilerplate conventions: every response is wrapped in
> `{ data, meta }` by the transform middleware; every write validates its body
> with a Zod schema; errors are thrown as `AppError(message, statusCode)`.

## Data model (Prisma)

- **EntityName:** field (type), field (type), … — relations to other entities
- …

> Models live in `prisma/schema.prisma`. After editing, run `make db`
> (`prisma db push`) and `make generate`.

## Validation rules

- `POST /api/<resource>` requires: _fields + constraints_
- Enums / formats / limits worth calling out: _…_

## Conventions in force

- Response envelope: `{ data, meta: { timestamp, statusCode } }` (automatic).
- Status codes: 200 read/update, 201 create, 204 delete, 400 validation,
  404 not found.
- Pagination: list endpoints accept `?page=&limit=` and return
  `{ data, meta: { total, page, limit, totalPages } }` (no list endpoint exists yet).
- Auth: this boilerplate ships **no auth**. If the brief needs it, decide the
  posture here and record it in `DECISIONS.md` before adding any.

## Open questions

1. _question for the user to answer before approval_

---

## Feature decomposition (filled after approval)

Once **Approved** is ticked, the agent splits this blueprint into entries in
[feature_list.json](feature_list.json), one feature per resource or substantial
behavior. Reference the resource `#` from the table above in each feature's
`notes`.

---
name: add-table
description: Build a sortable, filterable list using the DataTable composite (TanStack Table over Mantine's Table) wired to a query hook. Covers column definitions, the filter box, row selection and row actions, empty and loading states, and responsive column hiding. Use when the user asks to add a list page, a table, a "view X" page, or anything that renders a collection.
---

# add-table — sortable, filterable data with TanStack Table

`DataTable` (`src/components/data-table.tsx`) is the app's one table. TanStack
Table v8 stays headless and owns sorting, the global filter and row identity;
Mantine's `Table` draws it. Give it columns, data and a `getRowId`, and it
renders the whole thing — do not hand-roll the sort and filter wiring, and never
a raw `<table>` (`ui-lint` fails the build on one).

## Read these first

- `src/components/data-table.tsx` — read `DataTableProps`: `columns`, `data`,
  `getRowId`, `isLoading`, `onRowClick`, `selectedRowId`, `filter`,
  `filterPlaceholder`, `empty`.
- `src/pages/Projects/project-columns.tsx` — the reference slice. Copy this file
  for a new resource and change only the accessors.
- `src/pages/Projects/ProjectsPage.tsx` — the table inside a `list` page: filter pinned above it, rows owning the one scroll region.
- `docs/principles/spacing-and-type.md` — table density follows the 4px scale.

## The recipe

For a new list page (e.g. `/invoices`):

1. **Column definitions** — `src/pages/<Resource>/<resource>-columns.tsx`:

```tsx
import type { ColumnDef } from '@tanstack/react-table';
import { ActionIcon, Menu, Text } from '@mantine/core';
import { MoreHorizontal } from 'lucide-react';

import type { Invoice } from '@/api/types';
import { StatusBadge } from '@/pages/Projects/StatusBadge';
import cols from './invoice-columns.module.css';

export const invoiceColumns: ColumnDef<Invoice, unknown>[] = [
  {
    accessorKey: 'number',
    header: 'Number',
    cell: ({ row }) => (
      <Text size="sm" ff="monospace">
        {row.original.number}
      </Text>
    ),
  },
  {
    accessorKey: 'amount',
    header: 'Amount',
    cell: ({ row }) => (
      <Text size="sm" style={{ fontVariantNumeric: 'tabular-nums' }}>
        {new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' }).format(
          row.original.amount,
        )}
      </Text>
    ),
    meta: { headClassName: cols.amount, cellClassName: cols.amount },
  },
  {
    accessorKey: 'status',
    header: 'Status',
    cell: ({ row }) => <StatusBadge status={row.original.status} />,
    meta: { headClassName: cols.status, cellClassName: cols.status },
  },
  {
    id: 'actions',
    header: '',
    enableSorting: false,
    cell: () => (
      <Menu position="bottom-end" width={160}>
        <Menu.Target>
          <ActionIcon variant="subtle" color="gray" aria-label="Row actions">
            <MoreHorizontal size={16} />
          </ActionIcon>
        </Menu.Target>
        <Menu.Dropdown>
          <Menu.Item>View</Menu.Item>
          <Menu.Item>Edit</Menu.Item>
          <Menu.Divider />
          <Menu.Item color="red">Delete</Menu.Item>
        </Menu.Dropdown>
      </Menu>
    ),
  },
];
```

2. **The widths** — `src/pages/<Resource>/<resource>-columns.module.css`. A
   width and a breakpoint are the two things a `style` prop cannot say, so they
   go in a CSS module and reach the cells through `meta`. `DataTable` names its
   own container `data-table`, so a `@container` query here follows the *pane*
   the table sits in rather than the window — which is what a resizable desktop
   split needs:

```css
.amount {
  width: 7rem;
}

.status {
  display: none;
  width: 7rem;
}

@container data-table (min-width: 28rem) {
  .status {
    display: table-cell;
  }
}
```

3. **The page** — the query hook feeds the table, and the four states are the
   page's job:

```tsx
export function InvoicesPage() {
  const { data = [], isLoading, isError, error, refetch } = useInvoices();

  if (isError) return <ErrorState error={error} onRetry={refetch} />;

  return (
    <PageShell title="Invoices" description="All customer invoices." archetype="list" scroll={false}>
      <DataTable
        columns={invoiceColumns}
        data={data}
        getRowId={(row) => row.id}
        isLoading={isLoading}
        filterPlaceholder="Filter invoices…"
        empty={
          <EmptyState
            title="No invoices yet"
            description="Invoices appear here when customers are billed."
          />
        }
      />
    </PageShell>
  );
}
```

`isLoading` renders skeleton rows inside the table, so the header and the column
widths stay put while the data lands.

## Column patterns

| Pattern | How |
| --- | --- |
| Sortable header | the default — `DataTable` draws the sort control on any column TanStack says can sort |
| Not sortable | `enableSorting: false` (row actions, avatars) |
| Fixed / narrow column | `meta: { headClassName: cols.amount, … }` with `width` in the module — never a quoted class, which nothing emits |
| Hide on small panes | `display: none` in the module, `display: table-cell` inside `@container data-table (min-width: …)`, so it follows the pane and not the window |
| Numeric | `<Text style={{ fontVariantNumeric: 'tabular-nums' }}>` so digits line up between rows |
| Status | a `StatusBadge`, never an arbitrary colour |
| Date | formatted, never a raw ISO string |
| Actions | last column, `id: 'actions'`, no `accessorKey` |

## Selection and row click

`onRowClick` plus `selectedRowId` is the `list-detail` pattern: the row paints
itself selected with Mantine's own tone and the detail pane reads the same id.
For multi-select, add a checkbox column using Mantine `Checkbox` bound to
TanStack's `row.getIsSelected()` / `row.toggleSelected()`.

## Don'ts

- **Don't hand-roll a table.** No `<table>`, and no `flex` + `gap` grid pretending
  to be one — `ui-lint`'s `raw-table` rule fails the build.
- **Don't put a quoted class in `meta`.** `headClassName: 'w-28'` looks like it
  works and emits nothing — this app ships no utility classes, so the column has
  no width and no error says so. `meta` takes CSS-module hooks, and colour is
  Mantine's in the cell itself.
- **Don't sort strings with `localeCompare` without `{ numeric: true }`** —
  otherwise "Item 10" sorts before "Item 9".
- **Don't put the row-actions menu first.** It goes last, where the eye ends.
- **Don't filter by id.** Filter on what the user reads: number, name, email.

## Verify

1. Sort by every sortable column — the indicator flips and the rows reorder.
2. Type in the filter box — non-matching rows disappear; clearing restores them.
3. Tab through the table — focus moves through the interactive cells in order.
4. Open a row-actions menu — focus stays inside it until Esc.
5. Shrink the pane — the columns marked hidden drop out, the table still scrolls
   inside its own region rather than the page.
6. Toggle theme — the chrome swaps with the palette.

See `ux-prepass` for the mandatory UI gates.

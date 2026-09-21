import type { ColumnDef } from '@tanstack/react-table';
import { Group, Progress, Stack, Text } from '@mantine/core';

import type { Project } from '@/api/types';
import { StatusBadge } from '@/pages/Projects/StatusBadge';
import cols from './project-columns.module.css';

/**
 * Column definitions for the Projects list.
 *
 * Kept beside the page rather than inside `DataTable` so a new resource can copy
 * this file and change only the accessors — the table itself is generic.
 *
 * `meta` carries the two class hooks `DataTable` puts on the header cell and the
 * body cell. They are CSS-module classes, not utilities: the widths and the
 * container query live in `project-columns.module.css`, because a width that
 * only applies past a breakpoint is not something an inline style can say.
 */
export const projectColumns: ColumnDef<Project, unknown>[] = [
  {
    accessorKey: 'name',
    header: 'Name',
    cell: ({ row }) => (
      <Stack gap={0} style={{ minWidth: 0 }}>
        <Text size="sm" fw={500} truncate>
          {row.original.name}
        </Text>
        <Text size="xs" c="dimmed" truncate>
          {row.original.description}
        </Text>
      </Stack>
    ),
  },
  {
    accessorKey: 'status',
    header: 'Status',
    cell: ({ row }) => <StatusBadge status={row.original.status} />,
    meta: { headClassName: cols.status, cellClassName: cols.status },
  },
  {
    accessorKey: 'progress',
    header: 'Progress',
    cell: ({ row }) => (
      <Group gap="xs" wrap="nowrap">
        <Progress value={row.original.progress} size="sm" w={64} />
        <Text size="xs" c="dimmed" style={{ fontVariantNumeric: 'tabular-nums' }}>
          {row.original.progress}%
        </Text>
      </Group>
    ),
    meta: {
      // Hidden until the pane is wide enough rather than squeezed: a progress
      // bar under 64px is a decoration that no longer reads as a ratio.
      headClassName: cols.progress,
      cellClassName: cols.progress,
    },
  },
];

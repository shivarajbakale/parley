import type { Meta, StoryObj } from '@storybook/react';
import type { ColumnDef } from '@tanstack/react-table';

import { Badge, Button, Checkbox, EmptyState, Group, Text } from '@mantine/core';

import { DataTable } from './data-table';
import { eventArgTypes } from 'storybook/story-helpers';

/**
 * DataTable — TanStack Table with sortable column headers, a filter box, row
 * selection and row actions. Use it for any list where the user has to find
 * one row among many. A static, read-only table needs none of this; Mantine's
 * own `Table` is enough there.
 */
const meta = {
  title: 'Shell/Content/Data Table',
  component: DataTable,
  tags: ['autodocs'],
  parameters: { layout: 'fullscreen' },
  argTypes: {
    ...eventArgTypes(['onRowClick']),
    filterPlaceholder: {
      control: { type: 'text' },
      description: 'Placeholder for the filter box.',
      table: { category: 'Content' },
    },
    filter: {
      control: { type: 'boolean' },
      description: 'Set false to drop the filter box entirely.',
      table: { category: 'Appearance' },
    },
    isLoading: {
      control: { type: 'boolean' },
      description: 'Shows the loading body instead of rows.',
      table: { category: 'State' },
    },
  },
} satisfies Meta<typeof DataTable>;

export default meta;
type Story = StoryObj<typeof DataTable>;

type Project = {
  id: string;
  name: string;
  status: 'active' | 'paused' | 'archived';
  owner: string;
  updated: string;
};

const SAMPLE: Project[] = [
  { id: '1', name: 'Acme Web', status: 'active', owner: 'Shiv B.', updated: '2 hours ago' },
  { id: '2', name: 'Beta Mobile', status: 'paused', owner: 'Ada L.', updated: 'yesterday' },
  { id: '3', name: 'Gamma API', status: 'active', owner: 'Marcus K.', updated: '3 days ago' },
  { id: '4', name: 'Delta ETL', status: 'archived', owner: 'Yui N.', updated: 'last week' },
  { id: '5', name: 'Epsilon Mobile', status: 'active', owner: 'Priya R.', updated: 'just now' },
];

const COLUMNS: ColumnDef<Project, unknown>[] = [
  {
    id: 'select',
    header: ({ table }) => (
      <Checkbox
        checked={table.getIsAllPageRowsSelected()}
        onChange={(e) => table.toggleAllPageRowsSelected(e.currentTarget.checked)}
        aria-label="Select all"
      />
    ),
    cell: ({ row }) => (
      <Checkbox
        checked={row.getIsSelected()}
        onChange={(e) => row.toggleSelected(e.currentTarget.checked)}
        aria-label="Select row"
      />
    ),
    enableSorting: false,
    enableHiding: false,
  },
  {
    accessorKey: 'name',
    header: 'Name',
    cell: ({ row }) => (
      <Text size="sm" fw={500}>
        {String(row.getValue('name'))}
      </Text>
    ),
  },
  {
    accessorKey: 'status',
    header: 'Status',
    cell: ({ row }) => {
      const v = row.getValue('status') as Project['status'];
      const color = v === 'active' ? 'green' : v === 'paused' ? 'yellow' : 'gray';
      return (
        <Badge color={color} variant="light" size="sm">
          {v}
        </Badge>
      );
    },
  },
  { accessorKey: 'owner', header: 'Owner' },
  { accessorKey: 'updated', header: 'Updated' },
  {
    id: 'actions',
    header: '',
    cell: () => (
      <Group justify="flex-end">
        <Button variant="subtle" size="compact-xs">
          Open
        </Button>
      </Group>
    ),
  },
];

/** Five rows, sortable headers, the filter box on by default. */
export const Default: Story = {
  render: () => <DataTable columns={COLUMNS} data={SAMPLE} getRowId={(row) => row.id} />,
};

/** A named placeholder tells the user what the box filters. */
export const Filterable: Story = {
  name: 'With filter box',
  render: () => (
    <DataTable
      columns={COLUMNS}
      data={SAMPLE}
      getRowId={(row) => row.id}
      filterPlaceholder="Filter projects…"
    />
  ),
};

/** Selection state — the row reads as selected, not merely hovered. */
export const RowSelected: Story = {
  name: 'Row selected',
  render: () => (
    <DataTable
      columns={COLUMNS}
      data={SAMPLE}
      getRowId={(row) => row.id}
      selectedRowId="3"
      onRowClick={() => {}}
    />
  ),
};

/** No rows yet, with a single sentence in place of the body. */
export const Empty: Story = {
  render: () => (
    <DataTable
      columns={COLUMNS}
      data={[]}
      getRowId={(row: Project) => row.id}
      empty="No projects yet — create one to get started."
    />
  ),
};

/** The empty slot takes a node, so it can carry the action that fills the list. */
export const CustomEmpty: Story = {
  name: 'Custom empty state',
  render: () => (
    <DataTable
      columns={COLUMNS}
      data={[]}
      getRowId={(row: Project) => row.id}
      empty={
        <EmptyState
          title="Nothing here yet."
          description="Projects you create will show up in this list."
        >
          <Button size="xs">Create your first project</Button>
        </EmptyState>
      }
    />
  ),
};

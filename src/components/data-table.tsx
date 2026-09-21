import * as React from 'react';
import {
  flexRender,
  getCoreRowModel,
  getFilteredRowModel,
  getSortedRowModel,
  useReactTable,
  type ColumnDef,
  type SortingState,
} from '@tanstack/react-table';
import { Box, ScrollArea, Skeleton, Stack, Table, TextInput, UnstyledButton } from '@mantine/core';
import { ArrowDown, ArrowUp, ChevronsUpDown, Search } from 'lucide-react';

import styles from './data-table.module.css';


/**
 * The project's one data table: TanStack Table bound to Mantine's `Table`.
 *
 * TanStack stays headless and owns sorting, the global filter and row identity;
 * Mantine owns every pixel — the borders, the hover and selected row tones, the
 * sticky header. That split is why this composite survived the migration while
 * the kit around it did not: there is no Mantine data table, only a table, and
 * the sorting and filtering are ours.
 *
 * Build lists with this rather than a hand-written `<table>` — `ui-lint` fails
 * the build on the latter, and now that the kit is gone there is no exempt
 * directory left to write one in.
 */
export interface DataTableProps<TData> {
  columns: ColumnDef<TData, unknown>[];
  data: TData[];
  /** Stable row identity — also drives which row reads as selected. */
  getRowId: (row: TData) => string;
  isLoading?: boolean;
  onRowClick?: (row: TData) => void;
  selectedRowId?: string | null;
  /** Placeholder for the filter box. Omit the box entirely with `filter={false}`. */
  filterPlaceholder?: string;
  filter?: boolean;
  /** Rendered in place of the body when there are no rows. */
  empty?: React.ReactNode;
}

export function DataTable<TData>({
  columns,
  data,
  getRowId,
  isLoading,
  onRowClick,
  selectedRowId,
  filterPlaceholder = 'Filter…',
  filter = true,
  empty,
}: DataTableProps<TData>) {
  const [sorting, setSorting] = React.useState<SortingState>([]);
  const [globalFilter, setGlobalFilter] = React.useState('');

  const table = useReactTable({
    data,
    columns,
    state: { sorting, globalFilter },
    getRowId: row => getRowId(row),
    onSortingChange: setSorting,
    onGlobalFilterChange: setGlobalFilter,
    getCoreRowModel: getCoreRowModel(),
    getSortedRowModel: getSortedRowModel(),
    getFilteredRowModel: getFilteredRowModel(),
  });

  const rows = table.getRowModel().rows;
  const showEmpty = !isLoading && rows.length === 0;

  return (
    <Stack gap={0} h="100%" className={styles.root} style={{ minHeight: 0 }}>
      {filter && (
        <Box
          px="xs"
          py={6}
          style={{
            flexShrink: 0,
            borderBottom: '1px solid var(--mantine-color-default-border)',
          }}
        >
          <TextInput
            value={globalFilter}
            onChange={e => setGlobalFilter(e.currentTarget.value)}
            placeholder={filterPlaceholder}
            aria-label={filterPlaceholder}
            size="xs"
            variant="unstyled"
            leftSection={<Search size={14} />}
          />
        </Box>
      )}

      <ScrollArea style={{ minHeight: 0, flex: 1 }}>
        <Table
          stickyHeader
          highlightOnHover={!!onRowClick}
          verticalSpacing="xs"
          horizontalSpacing="md"
          striped={false}
        >
          <Table.Thead>
            {table.getHeaderGroups().map(headerGroup => (
              <Table.Tr key={headerGroup.id}>
                {headerGroup.headers.map(header => {
                  const sortable = header.column.getCanSort();
                  const sorted = header.column.getIsSorted();
                  return (
                    <Table.Th
                      key={header.id}
                      className={header.column.columnDef.meta?.headClassName}
                    >
                      {header.isPlaceholder ? null : sortable ? (
                        <UnstyledButton
                          component="button"
                          type="button"
                          onClick={header.column.getToggleSortingHandler()}
                          fz="inherit"
                          fw="inherit"
                          c="inherit"
                          style={{ display: 'inline-flex', alignItems: 'center', gap: 4 }}
                        >
                          {flexRender(header.column.columnDef.header, header.getContext())}
                          {sorted === 'asc' ? (
                            <ArrowUp size={12} />
                          ) : sorted === 'desc' ? (
                            <ArrowDown size={12} />
                          ) : (
                            <ChevronsUpDown size={12} className={styles.sortHint} />
                          )}
                        </UnstyledButton>
                      ) : (
                        flexRender(header.column.columnDef.header, header.getContext())
                      )}
                    </Table.Th>
                  );
                })}
              </Table.Tr>
            ))}
          </Table.Thead>

          <Table.Tbody>
            {isLoading &&
              Array.from({ length: 8 }).map((_, i) => (
                <Table.Tr key={`skeleton-${i}`}>
                  <Table.Td colSpan={columns.length}>
                    <Skeleton height={20} data-slot="skeleton" />
                  </Table.Td>
                </Table.Tr>
              ))}

            {rows.map(row => (
              <Table.Tr
                key={row.id}
                // Mantine's own selected tone, so a selected row reads the same
                // here as a selected item anywhere else in the app.
                bg={selectedRowId === row.id ? 'var(--mantine-color-default-hover)' : undefined}
                data-state={selectedRowId === row.id ? 'selected' : undefined}
                onClick={onRowClick ? () => onRowClick(row.original) : undefined}
                style={onRowClick ? { cursor: 'pointer' } : undefined}
              >
                {row.getVisibleCells().map(cell => (
                  <Table.Td key={cell.id} className={cell.column.columnDef.meta?.cellClassName}>
                    {flexRender(cell.column.columnDef.cell, cell.getContext())}
                  </Table.Td>
                ))}
              </Table.Tr>
            ))}
          </Table.Tbody>
        </Table>

        {showEmpty && <Box py="xl">{empty}</Box>}
      </ScrollArea>
    </Stack>
  );
}

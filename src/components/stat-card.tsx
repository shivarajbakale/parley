import * as React from 'react';
import { Group, Paper, Progress, Skeleton, Text } from '@mantine/core';
import { ArrowDownRight, ArrowUpRight, type LucideIcon } from 'lucide-react';

/**
 * Inline sparkline — a tiny SVG that fits inside a `<StatCard>`. No external
 * dep (we already pull recharts for the dashboard chart, but pulling it here
 * just for a 12-line sparkline would balloon the StatCard's coupling).
 *
 * Renders `null` when fewer than 2 points are passed in; otherwise draws a
 * filled gradient + line that scales to the available width. It paints in
 * `currentColor`, so the one colour decision is the `c` on its wrapper.
 */
function Sparkline({ values }: { values: number[] }) {
  if (values.length < 2) return null;
  const w = 100;
  const h = 24;
  const min = Math.min(...values);
  const max = Math.max(...values);
  const range = max - min || 1;
  const stepX = w / (values.length - 1);

  const linePath = values
    .map((v, i) => {
      const x = i * stepX;
      const y = h - ((v - min) / range) * (h - 4) - 2;
      return `${i === 0 ? 'M' : 'L'}${x.toFixed(2)},${y.toFixed(2)}`;
    })
    .join(' ');
  const areaPath = `${linePath} L${w.toFixed(2)},${h} L0,${h} Z`;

  return (
    <svg
      aria-hidden
      viewBox={`0 0 ${w} ${h}`}
      preserveAspectRatio="none"
      height={24}
      style={{ display: 'block', width: '100%', marginTop: 'var(--mantine-spacing-sm)' }}
    >
      <path d={areaPath} fill="currentColor" fillOpacity={0.12} />
      <path
        d={linePath}
        fill="none"
        stroke="currentColor"
        strokeWidth={1.5}
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  );
}

/** KPI tile used on the dashboard. Tabular numerals, optional trend delta,
 *  optional sparkline (an array of recent values the tile draws as a tiny
 *  line). Pass `series` to opt in to the sparkline; otherwise the tile stays
 *  a plain label/value/delta. */
export function StatCard({
  label,
  value,
  delta,
  icon: Icon,
  loading,
  series,
  progress,
  sub,
  ...props
}: {
  label: string;
  value: string;
  delta?: number;
  icon?: LucideIcon;
  loading?: boolean;
  /** Recent values — when provided (>=2 entries), draws a sparkline below the value. */
  series?: number[];
  /** Optional 0–1 progress bar shown below the value (e.g. seats used / total). */
  progress?: number;
  /** Optional caption rendered below the value (inside the card, above the
   *  sparkline / progress bar). */
  sub?: string;
} & React.ComponentProps<typeof Paper>) {
  const positive = (delta ?? 0) >= 0;
  return (
    <Paper withBorder radius="md" p="md" {...props}>
      <Group justify="space-between" wrap="nowrap">
        <Text size="xs" fw={500} c="dimmed">
          {label}
        </Text>
        {Icon && <Icon size={16} style={{ color: 'var(--mantine-color-dimmed)' }} />}
      </Group>
      <Group justify="space-between" align="flex-end" gap="xs" wrap="nowrap" mt={10}>
        {loading ? (
          <Skeleton height={32} width={64} radius="sm" />
        ) : (
          <Text fz={26} fw={600} lh={1.1} style={{ fontVariantNumeric: 'tabular-nums' }}>
            {value}
          </Text>
        )}
        {!loading && delta !== undefined && (
          <Group gap={2} wrap="nowrap">
            {positive ? (
              <ArrowUpRight size={14} />
            ) : (
              <ArrowDownRight size={14} />
            )}
            <Text size="xs" fw={500} c={positive ? 'green' : 'red'}>
              {Math.abs(delta)}%
            </Text>
          </Group>
        )}
      </Group>
      {!loading && series && (
        <Text component="div" c="brand">
          <Sparkline values={series} />
        </Text>
      )}
      {!loading && progress !== undefined && (
        <Progress value={Math.min(100, Math.max(0, progress * 100))} size="xs" mt="sm" />
      )}
      {!loading && sub && (
        <Text size="xs" c="dimmed" mt={6}>
          {sub}
        </Text>
      )}
    </Paper>
  );
}

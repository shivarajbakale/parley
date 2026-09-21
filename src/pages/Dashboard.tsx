import * as React from 'react';
import { Link } from '@tanstack/react-router';
import { Activity, ArrowRight, CheckCircle2, FolderKanban, Plus, X } from 'lucide-react';
import { BarChart } from '@mantine/charts';

import {
  ActionIcon,
  Box,
  Button,
  Code,
  EmptyState,
  Flex,
  Group,
  List,
  Paper,
  ScrollArea,
  SimpleGrid,
  Skeleton,
  Text,
  ThemeIcon,
} from '@mantine/core';

import { useProjects } from '@/hooks/useProjects';
import { PageShell } from '@/components/page-shell';
import { StatCard } from '@/components/stat-card';

/**
 * Dashboard — an overview of the Projects slice.
 *
 * Every number on this screen is derived from the same `useProjects()` query the
 * rest of the app uses. Nothing here is hardcoded: a starter that ships invented
 * metrics teaches the wrong pattern and leaves the user deleting fakes before
 * they can build anything.
 */
const DISMISS_KEY = 'dashboard:getting-started-dismissed';

/**
 * One series, named once. `@mantine/charts` wraps recharts and takes its colour
 * from the theme, so the chart cannot drift from the palette the way a
 * hand-passed `fill` does.
 */
const SERIES = [{ name: 'progress', label: 'Progress', color: 'brand.6' }];

export function Dashboard() {
  const { data: projects, isLoading } = useProjects();
  const [showGuide, setShowGuide] = React.useState(
    () => localStorage.getItem(DISMISS_KEY) !== 'true'
  );

  const dismissGuide = () => {
    localStorage.setItem(DISMISS_KEY, 'true');
    setShowGuide(false);
  };

  const all = projects ?? [];
  const active = all.filter((p) => p.status === 'active').length;
  const archived = all.filter((p) => p.status === 'archived').length;
  const averageProgress = all.length
    ? Math.round(all.reduce((sum, p) => sum + p.progress, 0) / all.length)
    : 0;

  const chartData = [...all]
    .sort((a, b) => b.progress - a.progress)
    .slice(0, 6)
    .map((p) => ({ name: p.name, progress: p.progress }));

  return (
    <PageShell
      title="Dashboard"
      description="A snapshot of your workspace."
      archetype="dashboard-grid"
      scroll={false}
      bodyProps={{
        display: 'flex',
        style: { flexDirection: 'column', minHeight: 0, gap: 'var(--mantine-spacing-md)' },
      }}
      actions={
        <Button component={Link} to="/projects" leftSection={<Plus size={16} />}>
          New project
        </Button>
      }
    >
      <SimpleGrid cols={{ base: 2, lg: 4 }} spacing="sm" style={{ flexShrink: 0 }}>
        <StatCard label="Projects" value={String(all.length)} icon={FolderKanban} loading={isLoading} />
        <StatCard label="Active" value={String(active)} icon={Activity} loading={isLoading} />
        <StatCard
          label="Average progress"
          value={`${averageProgress}%`}
          icon={CheckCircle2}
          loading={isLoading}
        />
        <StatCard label="Archived" value={String(archived)} icon={FolderKanban} loading={isLoading} />
      </SimpleGrid>

      <Flex
        direction={{ base: 'column', lg: 'row' }}
        gap="md"
        style={{ flex: 1, minHeight: 0 }}
      >
        <Paper
          withBorder
          radius="md"
          p={0}
          data-panel="chart"
          style={{
            flex: 2,
            display: 'flex',
            flexDirection: 'column',
            minHeight: 0,
            overflow: 'hidden',
          }}
        >
          <Group
            component="header"
            justify="space-between"
            px="md"
            py="sm"
            style={{
              flexShrink: 0,
              borderBottom: '1px solid var(--mantine-color-default-border)',
            }}
          >
            <Box>
              <Text component="h2" size="sm" fw={500}>
                Progress by project
              </Text>
              <Text size="xs" c="dimmed">
                Top {chartData.length} by completion.
              </Text>
            </Box>
            <Button
              component={Link}
              to="/projects"
              variant="subtle"
              color="gray"
              size="xs"
              rightSection={<ArrowRight size={14} />}
            >
              View all
            </Button>
          </Group>

          <Box p="md" style={{ flex: 1, minHeight: 0, overflow: 'hidden' }}>
            {isLoading ? (
              <Skeleton height="100%" />
            ) : chartData.length === 0 ? (
              <EmptyState
                icon={<FolderKanban size={20} />}
                title="No data yet"
                description="Create a project and its progress shows up here."
              />
            ) : (
              <BarChart
                h="100%"
                data={chartData}
                dataKey="name"
                orientation="vertical"
                series={SERIES}
                barProps={{ radius: 4, barSize: 16 }}
                gridAxis="y"
                xAxisProps={{ domain: [0, 100] }}
                yAxisProps={{
                  width: 110,
                  tickFormatter: (value: string) =>
                    value.length > 16 ? `${value.slice(0, 15)}…` : value,
                }}
                withTooltip
              />
            )}
          </Box>
        </Paper>

        {showGuide ? (
          <Paper
            withBorder
            radius="md"
            p="md"
            pos="relative"
            style={{
              flex: 1,
              display: 'flex',
              flexDirection: 'column',
              minHeight: 0,
              overflow: 'hidden',
            }}
          >
            <ActionIcon
              variant="subtle"
              color="gray"
              size="sm"
              aria-label="Dismiss"
              onClick={dismissGuide}
              pos="absolute"
              top={8}
              right={8}
            >
              <X size={14} />
            </ActionIcon>
            <ScrollArea style={{ flex: 1, minHeight: 0 }}>
            <Text component="h2" size="sm" fw={500}>
              Getting started
            </Text>
            <Text size="sm" c="dimmed" mt={4}>
              This shell is your starting point. Build your first feature end-to-end.
            </Text>
            <List type="ordered" listStyleType="none" spacing="sm" mt="md">
              <Step n={1}>
                Explore the <b>Projects</b> slice — the reference feature.
              </Step>
              <Step n={2}>
                Run the <Code>add-feature</Code> skill to scaffold your own resource.
              </Step>
              <Step n={3}>Press ⌘K to jump anywhere.</Step>
            </List>
            </ScrollArea>
            <Button
              component={Link}
              to="/projects"
              variant="default"
              size="xs"
              fullWidth
              mt="sm"
              style={{ flexShrink: 0 }}
            >
              Open Projects
            </Button>
          </Paper>
        ) : (
          <Paper
            withBorder
            radius="md"
            p="md"
            style={{
              flex: 1,
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              minHeight: 0,
              overflow: 'hidden',
              borderStyle: 'dashed',
            }}
          >
            <Text size="sm" c="dimmed">
              Your next panel goes here. Add one with the <Code>add-ui-component</Code> skill.
            </Text>
          </Paper>
        )}
      </Flex>
    </PageShell>
  );
}

function Step({ n, children }: { n: number; children: React.ReactNode }) {
  return (
    <List.Item styles={{ itemWrapper: { alignItems: 'flex-start' } }}>
      <Group gap="sm" wrap="nowrap" align="flex-start">
        <ThemeIcon size={20} radius="xl" variant="default">
          <Text size="xs" fw={500}>
            {n}
          </Text>
        </ThemeIcon>
        <Text component="span" size="sm" c="dimmed">
          {children}
        </Text>
      </Group>
    </List.Item>
  );
}

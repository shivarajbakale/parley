import * as React from 'react';
import { Box, Flex, Group, ScrollArea, Stack, Text, Title, type BoxProps } from '@mantine/core';

/** Layout shapes the UI probe knows how to check. See scripts/ui-probe/rules/archetype.ts. */
export type Archetype = 'list-detail' | 'dashboard-grid' | 'form' | 'centered-card';

/**
 * Every page renders through this.
 *
 * The app shell is a fixed viewport (`App.tsx` is `100svh` with
 * `overflow: hidden`), so a page must never scroll as a whole. `PageShell` pins
 * the title band and the optional toolbar, and gives the body the single scroll
 * region on screen.
 *
 * Pages that manage their own panes — the Projects master-detail view, for
 * instance — pass `scroll={false}` and take responsibility for scrolling inside
 * each pane. Anything else is a lint failure (`scripts/ui-lint.mjs`).
 *
 * The responsive header row is `Flex direction={{ base, sm }}` rather than a
 * breakpoint-prefixed class: Mantine emits the media query from the theme's own
 * breakpoints, so the shell and the components inside it break at the same
 * width by construction.
 */
export function PageShell({
  title,
  description,
  actions,
  toolbar,
  scroll = true,
  bodyProps,
  archetype,
  children,
}: {
  title: string;
  description?: string;
  /** Right-aligned controls in the title band. */
  actions?: React.ReactNode;
  /** Secondary row beneath the title — filters, tabs, segmented controls. */
  toolbar?: React.ReactNode;
  scroll?: boolean;
  /** Extra props for the body box — padding overrides, mostly. */
  bodyProps?: BoxProps;
  /**
   * The layout shape this page promises to hold. Published to the DOM as
   * `data-archetype` so the UI probe can check the promise instead of guessing.
   */
  archetype?: Archetype;
  children: React.ReactNode;
}) {
  return (
    <Stack
      component="section"
      gap={0}
      h="100%"
      style={{ minHeight: 0 }}
      data-archetype={archetype}
    >
      <Flex
        component="header"
        direction={{ base: 'column', sm: 'row' }}
        align={{ base: 'stretch', sm: 'flex-end' }}
        justify="space-between"
        gap="sm"
        px="lg"
        pt="lg"
        pb="md"
        style={{ flexShrink: 0 }}
      >
        <Stack gap={4}>
          <Title order={1} size="h4">
            {title}
          </Title>
          {description && (
            <Text size="sm" c="dimmed">
              {description}
            </Text>
          )}
        </Stack>
        {actions && (
          <Group gap="xs" wrap="nowrap" style={{ flexShrink: 0 }}>
            {actions}
          </Group>
        )}
      </Flex>

      {toolbar && (
        <Box px="lg" pb="md" style={{ flexShrink: 0 }}>
          {toolbar}
        </Box>
      )}

      {scroll ? (
        <ScrollArea style={{ minHeight: 0, flex: 1 }}>
          <Box px="lg" pb="lg" {...bodyProps}>
            {children}
          </Box>
        </ScrollArea>
      ) : (
        <Box px="lg" pb="lg" style={{ minHeight: 0, flex: 1 }} {...bodyProps}>
          {children}
        </Box>
      )}
    </Stack>
  );
}

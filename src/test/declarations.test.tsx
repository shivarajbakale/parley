import { describe, expect, it } from 'vitest';
import { render, screen } from '@testing-library/react';

import { Button, Card, Paper } from '@mantine/core';

import { ThemeProvider } from '@/components/theme-provider';
import { PageShell } from '@/components/page-shell';

/**
 * The UI probe reads intent off the DOM rather than inferring it. These three
 * attributes are that contract: without them the archetype, panel and
 * primary-action rules have nothing to key on.
 *
 * Two of them used to come from kit atoms that set them as literal props. The
 * kit is gone and they come from `theme.components` now — which is the more
 * fragile arrangement, because a default prop is invisible at the call site and
 * a page that passes its own `undefined` silently gets the default back. So
 * these assertions matter more than they did, not less.
 */
/**
 * Mantine components read the theme through context, so anything mounting one
 * throws outside `MantineProvider` — including `PageShell`, which is a Box.
 * Every render here goes through the provider for that reason, and because a
 * test tree that differs from the app tree measures a different component.
 */
const renderUI = (ui: React.ReactNode) =>
  render(<ThemeProvider defaultTheme="dark" storageKey="declarations-test">{ui}</ThemeProvider>);

describe('probe declarations', () => {
  it('PageShell publishes its archetype', () => {
    renderUI(
      <PageShell title="Projects" archetype="list-detail">
        <p>body</p>
      </PageShell>
    );
    const section = screen.getByText('body').closest('[data-archetype]');
    expect(section).not.toBeNull();
    expect(section).toHaveAttribute('data-archetype', 'list-detail');
  });

  it('PageShell omits the attribute when no archetype is declared', () => {
    renderUI(
      <PageShell title="Projects">
        <p>body</p>
      </PageShell>
    );
    expect(screen.getByText('body').closest('[data-archetype]')).toBeNull();
  });

  it('Paper and Card mark themselves as measurable panels', () => {
    renderUI(
      <>
        <Paper>paper body</Paper>
        <Card>card body</Card>
      </>
    );
    expect(screen.getByText('paper body')).toHaveAttribute('data-panel', 'card');
    expect(screen.getByText('card body')).toHaveAttribute('data-panel', 'card');
  });

  it('Button publishes its variant, including the one it falls back to', () => {
    // Mantine renders `data-variant` only when a variant prop is passed, so an
    // un-varianted Button — the accented primary on every form in the app —
    // published nothing and probe rule B3 could not find a single submit.
    // `theme.components.Button` names the implicit default; this is the gate
    // that keeps it named.
    renderUI(
      <>
        <Button>Save</Button>
        <Button variant="subtle">Cancel</Button>
      </>
    );
    expect(screen.getByRole('button', { name: 'Save' })).toHaveAttribute('data-variant', 'filled');
    expect(screen.getByRole('button', { name: 'Cancel' })).toHaveAttribute(
      'data-variant',
      'subtle'
    );
  });
});

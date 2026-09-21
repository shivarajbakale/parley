import { describe, expect, it } from 'vitest';
import { fireEvent, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';

import { ProjectsPage } from '@/pages/Projects/ProjectsPage';
import { renderProjects } from './render';

/**
 * The layout contract, asserted at runtime.
 *
 * `scripts/ui-lint.mjs` in the generating repo catches hand-rolled markup
 * statically; these tests cover the behaviour that lint cannot see — that the
 * master-detail view keeps the list mounted when a project is selected, and that
 * the page header stays put instead of scrolling away.
 */
describe('Projects master-detail', () => {
  it('renders the list from the mock API', async () => {
    renderProjects(ProjectsPage);

    expect(await screen.findByText('Billing v2')).toBeInTheDocument();
    expect(screen.getByText('API Gateway')).toBeInTheDocument();
  });

  it('fills the detail pane without unmounting the list', async () => {
    const user = userEvent.setup();
    renderProjects(ProjectsPage);

    // Before selection the right pane is an explicit empty state, not a blank.
    expect(await screen.findByText('Nothing selected')).toBeInTheDocument();

    await user.click(await screen.findByText('Billing v2'));

    // Detail arrived...
    expect(await screen.findByRole('tab', { name: 'Overview' })).toBeInTheDocument();
    await waitFor(() => expect(screen.queryByText('Nothing selected')).not.toBeInTheDocument());

    // ...and the list is still there. This is the whole point of master-detail:
    // selecting a row must not navigate the user away from their place.
    expect(screen.getByText('API Gateway')).toBeInTheDocument();
  });

  it('keeps the page header outside the scroll region', async () => {
    renderProjects(ProjectsPage);

    const heading = await screen.findByRole('heading', { name: 'Projects', level: 1 });

    // The header must not live inside a Radix scroll viewport — if it does, it
    // scrolls away with the content and the shell's fixed-viewport contract is
    // broken.
    expect(heading.closest('[data-slot="scroll-area-viewport"]')).toBeNull();
  });

  it('filters the list without a page reload', async () => {
    renderProjects(ProjectsPage);

    await screen.findByText('Billing v2');

    // `fireEvent` rather than `userEvent` here: react-resizable-panels calls
    // preventDefault on pointerdown when it believes the pointer is over a drag
    // handle, and under jsdom every getBoundingClientRect is a zero rect at the
    // origin, so it always believes that. Clicks still dispatch — only focus is
    // suppressed — so this is a jsdom artifact, not app behaviour.
    fireEvent.change(screen.getByPlaceholderText('Filter projects…'), {
      target: { value: 'Gateway' },
    });

    await waitFor(() => expect(screen.queryByText('Billing v2')).not.toBeInTheDocument());
    expect(screen.getByText('API Gateway')).toBeInTheDocument();
  });

  it('creates a project from the dialog, not a separate page', async () => {
    const user = userEvent.setup();
    renderProjects(ProjectsPage);

    await screen.findByText('Billing v2');
    await user.click(screen.getByRole('button', { name: /new project/i }));

    const dialog = await screen.findByRole('dialog');
    await user.type(within(dialog).getByLabelText('Name'), 'Test Project');
    await user.click(within(dialog).getByRole('button', { name: /create project/i }));

    expect(await screen.findByRole('tab', { name: 'Overview' })).toBeInTheDocument();
  });
});

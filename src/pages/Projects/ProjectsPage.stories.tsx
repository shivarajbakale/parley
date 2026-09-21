import type { Meta, StoryObj } from '@storybook/react';
import { delay, http, HttpResponse } from 'msw';

import { mswSession, withMemoryRouter } from '../../../.storybook/tanstack-router-decorator';
import { ProjectsPage } from './ProjectsPage';

/**
 * Projects list + resizable detail pane (the app's master–detail pattern).
 * Data comes from the shared MSW handlers, so this story and `npm run dev`
 * show identical fixtures.
 */
const meta = {
  title: 'Pages/Projects',
  component: ProjectsPage,
  tags: ['autodocs'],
  parameters: { layout: 'fullscreen' },
  ...mswSession,
  decorators: [withMemoryRouter('/projects')],
} satisfies Meta<typeof ProjectsPage>;

export default meta;
type Story = StoryObj<typeof ProjectsPage>;

export const Populated: Story = {};

export const Empty: Story = {
  beforeEach: ({ msw }) => {
    msw.use(http.get('/api/projects', () => HttpResponse.json({ success: true, data: [] })));
  },
};

/** Query in flight — the list rail shows its skeleton rows. */
export const Loading: Story = {
  beforeEach: ({ msw }) => {
    msw.use(
      http.get('/api/projects', async () => {
        await delay('infinite');
        return HttpResponse.json({ success: true, data: [] });
      }),
    );
  },
};

/** Backend 500 — the master-detail frame survives; only the rail reports. */
export const LoadError: Story = {
  name: 'Load error',
  beforeEach: ({ msw }) => {
    msw.use(
      http.get('/api/projects', () =>
        HttpResponse.json({ success: false, error: 'Upstream unavailable' }, { status: 500 }),
      ),
    );
  },
};

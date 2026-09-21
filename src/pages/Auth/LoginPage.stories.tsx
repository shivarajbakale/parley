import type { Meta, StoryObj } from '@storybook/react';
import { expect, userEvent, waitFor, within } from 'storybook/test';

import { withMemoryRouter } from '../../../.storybook/tanstack-router-decorator';
import { LoginPage } from './LoginPage';

/** Public sign-in route (renders bare — no app chrome). Submitting empty shows Zod errors. */
const meta = {
  title: 'Pages/Login',
  component: LoginPage,
  tags: ['autodocs'],
  parameters: { layout: 'fullscreen' },
  decorators: [withMemoryRouter('/login')],
} satisfies Meta<typeof LoginPage>;

export default meta;
type Story = StoryObj<typeof LoginPage>;

// LoginPage redirects to `/` when a `demo-session` is already in localStorage
// (the dev auto-login path). In storybook the iframe shares localStorage with
// the manager and `demo-session` may already be present from earlier sessions,
// which would bounce us straight off the form. Clear it so the form actually
// renders here.
const noAutoLogin = {
  beforeEach() {
    if (typeof localStorage !== 'undefined') localStorage.removeItem('demo-session');
  },
};

export const Idle: Story = {
  ...noAutoLogin,
};

/** Submitting an empty form — Zod surfaces a message under each field. */
export const ValidationErrors: Story = {
  ...noAutoLogin,
  name: 'Validation errors',
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement);
    await userEvent.click(canvas.getByRole('button', { name: /^sign in$/i }));
    await waitFor(
      () => {
        const email = canvas.getByPlaceholderText('you@example.com');
        expect(email).toHaveAttribute('aria-invalid', 'true');
      },
      { timeout: 3000 },
    );
  },
};

/** Credentials typed, ready to submit — the populated counterpart to `Idle`. */
export const Filled: Story = {
  ...noAutoLogin,
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement);
    await userEvent.type(canvas.getByPlaceholderText('you@example.com'), 'ada@example.com');
    await userEvent.type(canvas.getByPlaceholderText('••••••••'), 'correct-horse-battery');
  },
};

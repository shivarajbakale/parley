import type { Meta, StoryObj } from '@storybook/react';
import { expect, userEvent, waitFor } from 'storybook/test';

import { mswSession, withMemoryRouter } from '../../.storybook/tanstack-router-decorator';
import { withSidebar } from '../../.storybook/shell-decorators';
import { NavUser } from './nav-user';

/**
 * Navbar footer account chip. Opens a menu with upgrade / settings / sign-out.
 *
 * Unlike `AccountMenu` (the top-right chip), this one is drawn at the navbar's
 * width and has two shapes: the full chip, and the rail, where there is no room
 * for a name and an email so it collapses to the avatar alone. The identity
 * still appears — in the dropdown, which is where it was going to be read.
 *
 * The user comes from `useSession()`, so these stories vary `railed` rather
 * than passing a fixture in.
 */
const meta = {
  title: 'Shell/Layout/Nav User',
  component: NavUser,
  tags: ['autodocs'],
  parameters: { layout: 'fullscreen' },
  argTypes: {
    railed: {
      control: { type: 'boolean' },
      description:
        'Icon-only mode. The name and email drop out of the chip; both still appear in the dropdown.',
      table: { category: 'Appearance' },
    },
  },
  ...mswSession,
  decorators: [withMemoryRouter('/'), withSidebar],
  args: { railed: false },
} satisfies Meta<typeof NavUser>;

export default meta;
type Story = StoryObj<typeof NavUser>;

/** The full chip: avatar, name, email, and the trailing ⇅ chevron. */
export const Default: Story = {};

/** The rail. Avatar only — the name would be clipped, not shrunk. */
export const Railed: Story = {
  name: 'Railed (icon only)',
  args: { railed: true },
};

/** Click the chip — the menu opens with its three groups. */
export const MenuOpen: Story = {
  name: 'Menu open',
  play: async () => {
    const trigger = document.body.querySelector('[aria-label="Account menu"]');
    expect(trigger).toBeTruthy();
    await userEvent.click(trigger as HTMLElement);
    await waitFor(() => {
      expect(document.body.textContent).toContain('Upgrade plan');
      expect(document.body.textContent).toContain('Log out');
      expect(document.body.textContent).toContain('Settings');
    });
  },
};

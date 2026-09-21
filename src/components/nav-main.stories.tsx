import type { Meta, StoryObj } from '@storybook/react';
import {
  FolderKanban,
  Inbox,
  LayoutDashboard,
  Settings,
  Star,
  Users,
} from 'lucide-react';

import { mswSession, withMemoryRouter } from '../../.storybook/tanstack-router-decorator';
import { withSidebar } from '../../.storybook/shell-decorators';
import { NavMain, type NavMainItem } from './nav-main';
import { navItems } from '@/config/nav';

/**
 * Primary sidebar navigation. Every entry is a Mantine `NavLink`: a flat one
 * when it has no children, a nested one — the disclosure comes free — when it
 * does.
 *
 * Two shapes, and the stories cover both. Expanded, an entry is an icon and a
 * label. Railed, there is no room for a label, so each entry collapses to a
 * tooltip-wrapped `ActionIcon` carrying the title as its `aria-label`; a group
 * flattens to its parent and navigates there.
 */
const meta = {
  title: 'Shell/Layout/Nav Main',
  component: NavMain,
  tags: ['autodocs'],
  parameters: { layout: 'fullscreen' },
  argTypes: {
    items: {
      control: { type: 'object' },
      description:
        'Nav entries. An entry with `items` renders as a nested NavLink; without, a flat one.',
      table: { category: 'Data' },
    },
    railed: {
      control: { type: 'boolean' },
      description: 'Icon-only mode. Labels move into tooltips and aria-labels.',
      table: { category: 'Appearance' },
    },
  },
  ...mswSession,
  decorators: [withMemoryRouter('/'), withSidebar],
} satisfies Meta<typeof NavMain>;

export default meta;
type Story = StoryObj<typeof NavMain>;

const FROM_CONFIG: NavMainItem[] = navItems.map(({ title, to, icon }) => ({
  title,
  url: to,
  icon,
}));

/**
 * The real list from `src/config/nav` — Dashboard / Projects / Settings. No
 * `isActive`, no children; each entry is a flat Link, so a click navigates.
 */
export const Default: Story = {
  name: 'Default (from nav config)',
  args: { items: FROM_CONFIG },
};

/**
 * Mixed: three flat entries plus two nested groups. Proves the disclosure
 * branch renders, that the chevron turns, and that the child list stays under
 * its parent rather than joining the top level.
 */
export const WithGroups: Story = {
  name: 'With nested groups',
  args: {
    items: [
      { title: 'Dashboard', url: '/', icon: LayoutDashboard },
      { title: 'Projects', url: '/projects', icon: FolderKanban },
      { title: 'Settings', url: '/settings', icon: Settings },
      {
        title: 'Workspaces',
        url: '/workspaces',
        icon: Users,
        items: [
          { title: 'Engineering', url: '/workspaces/eng' },
          { title: 'Design', url: '/workspaces/design' },
          { title: 'Operations', url: '/workspaces/ops' },
        ],
      },
      {
        title: 'Reports',
        url: '/reports',
        icon: Inbox,
        items: [
          { title: 'Weekly', url: '/reports/weekly' },
          { title: 'Monthly', url: '/reports/monthly' },
        ],
      },
    ],
  },
};

/**
 * Projects highlighted — `isActive` paints Mantine's active NavLink, and on a
 * group it is also what opens the branch the user is standing in.
 */
export const ActiveItem: Story = {
  name: 'Active item (Projects)',
  args: {
    items: FROM_CONFIG.map((item) => ({ ...item, isActive: item.url === '/projects' })),
  },
};

/**
 * The rail. Icons only, at 68px: the label survives as the tooltip and the
 * `aria-label`, so the entry is still named for a pointer and for a screen
 * reader both.
 */
export const Railed: Story = {
  name: 'Railed (icon only)',
  args: {
    items: FROM_CONFIG.map((item) => ({ ...item, isActive: item.url === '/projects' })),
    railed: true,
  },
};

/** Empty list — the group label still renders; there is simply nothing under it. */
export const Empty: Story = {
  name: 'Empty list',
  args: { items: [] },
};

/**
 * Twelve entries — a visual smoke test that nothing wraps badly and that the
 * navbar's own scroll area takes over when the list outgrows the column.
 */
export const LongList: Story = {
  name: 'Long list (12 items)',
  args: {
    items: [
      { title: 'Dashboard', url: '/', icon: LayoutDashboard },
      { title: 'Projects', url: '/projects', icon: FolderKanban },
      { title: 'Inbox', url: '/inbox', icon: Inbox },
      { title: 'Team', url: '/team', icon: Users },
      { title: 'Settings', url: '/settings', icon: Settings },
      { title: 'Starred', url: '/starred', icon: Star },
      { title: 'Pinned', url: '/pinned', icon: Star },
      { title: 'Archive', url: '/archive', icon: Inbox },
      { title: 'Trash', url: '/trash', icon: Inbox },
      { title: 'Reports', url: '/reports', icon: Inbox },
      { title: 'Audit log', url: '/audit', icon: Inbox },
      { title: 'Members', url: '/members', icon: Users },
    ],
  },
};

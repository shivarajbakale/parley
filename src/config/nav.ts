import { LayoutDashboard, FolderKanban, Settings, type LucideIcon } from 'lucide-react';

/**
 * Single source of truth for primary navigation.
 *
 * Consumed by the sidebar, the command palette (⌘K), and the topbar page title.
 * Add a routed page to the app by adding it here (and to `src/router/router.tsx`).
 * The `add-page` skill automates both edits.
 */
export interface NavItem {
  title: string;
  to: string;
  icon: LucideIcon;
  /** Extra search terms for the command palette. */
  keywords?: string;
}

export const navItems: NavItem[] = [
  { title: 'Dashboard', to: '/', icon: LayoutDashboard, keywords: 'home overview metrics' },
  { title: 'Projects', to: '/projects', icon: FolderKanban, keywords: 'workspaces repos items' },
  { title: 'Settings', to: '/settings', icon: Settings, keywords: 'account preferences profile theme' },
];

/** Human page title for a given pathname — used by the topbar. */
export function pageTitleFor(pathname: string): string {
  if (/^\/projects\/[^/]+$/.test(pathname)) return 'Projects';
  const match = navItems.find((i) => i.to === pathname);
  return match?.title ?? 'Console';
}

import { useSyncExternalStore } from 'react';

/**
 * The shell's navigation state — one store, two independent booleans.
 *
 * The shadcn sidebar kept this in a React context that only its own components
 * could read, which is why the topbar's toggle had to be a kit component too.
 * Mantine's `AppShell` takes the state as props instead, so it lives here: the
 * shell reads it to size the navbar, the topbar's controls write it, and
 * nothing has to be a descendant of anything.
 *
 * - `railed` is the desktop collapse. It persists, because a user who works in
 *   the rail expects the rail on the next visit; the width is a token below so
 *   the shell and the pieces inside it cannot disagree about it.
 * - `mobileOpen` is the overlay drawer. It deliberately does not persist —
 *   arriving to a navigation panel over the page is not a state anyone chose.
 *
 * `useSyncExternalStore` rather than a state library: this is two booleans and
 * one localStorage key, and a dependency added for that is a dependency the
 * next person has to keep current.
 */
export const NAVBAR_WIDTH = 256;
export const NAVBAR_RAIL_WIDTH = 68;

const STORAGE_KEY = 'shell:railed';

type ShellNavState = { railed: boolean; mobileOpen: boolean };

function readRailed(): boolean {
  try {
    return localStorage.getItem(STORAGE_KEY) === 'true';
  } catch {
    return false;
  }
}

let state: ShellNavState = { railed: readRailed(), mobileOpen: false };
const listeners = new Set<() => void>();

function set(next: Partial<ShellNavState>) {
  // A no-op write must stay a no-op. `App` closes the mobile drawer in an
  // effect on every navigation, and if that notified listeners regardless the
  // re-render would run the effect again — an update loop that only a real
  // browser sees, because it needs a router and a commit to close.
  if (Object.entries(next).every(([k, v]) => state[k as keyof ShellNavState] === v)) return;
  state = { ...state, ...next };
  if (next.railed !== undefined) {
    try {
      localStorage.setItem(STORAGE_KEY, String(next.railed));
    } catch {
      // A private window with storage blocked still gets a working shell; the
      // choice simply does not survive the session.
    }
  }
  listeners.forEach((l) => l());
}

const subscribe = (listener: () => void) => {
  listeners.add(listener);
  return () => listeners.delete(listener);
};

/** Server-render fallback: the expanded navbar, which is the safe first paint. */
const SERVER_STATE: ShellNavState = { railed: false, mobileOpen: false };

/**
 * The actions, defined once at module scope rather than per render.
 *
 * They close over the store, not over a render, so their identity is stable —
 * which is what lets a caller list `closeMobile` in an effect's dependency
 * array (`App` does) without the effect re-running on every commit.
 */
export const toggleRail = () => set({ railed: !state.railed });
export const setRailed = (value: boolean) => set({ railed: value });
export const toggleMobile = () => set({ mobileOpen: !state.mobileOpen });
export const closeMobile = () => set({ mobileOpen: false });

export function useShellNav() {
  const snapshot = useSyncExternalStore(
    subscribe,
    () => state,
    () => SERVER_STATE
  );

  return {
    railed: snapshot.railed,
    mobileOpen: snapshot.mobileOpen,
    toggleRail,
    setRailed,
    toggleMobile,
    closeMobile,
  };
}

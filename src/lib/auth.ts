import { useSyncExternalStore } from 'react';

/**
 * Demo authentication — a local, backend-free stand-in for a real auth client.
 *
 * This starter ships without a backend so it boots instantly. This module keeps
 * a "session" in localStorage and exposes the SAME surface a real client would
 * (`useSession`, `signIn`, `signUp`, `signOut`), so the login/signup pages,
 * `AuthGuard`, and the account menu are already wired.
 *
 * To go real: replace this file with your provider's client (e.g. Better Auth,
 * Clerk, Supabase) keeping these exports. Nothing else in the app changes.
 */

export interface DemoUser {
  id: string;
  name: string;
  email: string;
  image?: string | null;
}

export interface DemoSession {
  user: DemoUser;
  session: { id: string; token: string; expiresAt: string };
}

const STORAGE_KEY = 'demo-session';
const listeners = new Set<() => void>();

function persist(session: DemoSession | null) {
  try {
    if (session) localStorage.setItem(STORAGE_KEY, JSON.stringify(session));
    else localStorage.removeItem(STORAGE_KEY);
  } catch {
    /* storage unavailable — session lives in memory only */
  }
}

function loadInitial(): DemoSession | null {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    return raw ? (JSON.parse(raw) as DemoSession) : null;
  } catch {
    return null;
  }
}

// Cached so `getSnapshot` returns a stable reference (required by useSyncExternalStore).
let current: DemoSession | null = loadInitial();

function setSession(next: DemoSession | null) {
  current = next;
  persist(next);
  listeners.forEach((l) => l());
}

function subscribe(cb: () => void) {
  listeners.add(cb);
  return () => {
    listeners.delete(cb);
  };
}

function nameFromEmail(email: string): string {
  const base = email.split('@')[0] ?? 'there';
  return base
    .split(/[._-]+/)
    .filter(Boolean)
    .map((w) => w[0].toUpperCase() + w.slice(1))
    .join(' ');
}

function makeSession(email: string, name?: string): DemoSession {
  const id = crypto.randomUUID?.() ?? String(Date.now());
  return {
    user: { id, name: name || nameFromEmail(email), email },
    session: {
      id: `sess_${id}`,
      token: `demo_${id}`,
      expiresAt: new Date(Date.now() + 7 * 864e5).toISOString(),
    },
  };
}

/** Reactive current session. `{ data, isPending }` mirrors a real auth hook. */
export function useSession() {
  const data = useSyncExternalStore(
    subscribe,
    () => current,
    () => current
  );
  return { data, isPending: false, error: null, refetch: () => {} };
}

/** Mirrors a real client's result: `error` is `null` on success. */
type AuthResult = { data: DemoSession | null; error: { message: string } | null };

export async function getSession() {
  return { data: current, error: null };
}

export const signIn = {
  async email({ email }: { email: string; password: string }): Promise<AuthResult> {
    setSession(makeSession(email));
    return { data: current, error: null };
  },
};

export const signUp = {
  async email({
    email,
    name,
  }: {
    email: string;
    password: string;
    name?: string;
  }): Promise<AuthResult> {
    setSession(makeSession(email, name));
    return { data: current, error: null };
  },
};

export async function signOut() {
  setSession(null);
  return { data: { success: true }, error: null };
}

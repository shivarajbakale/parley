import { afterAll, afterEach, beforeAll } from 'vitest';
import { cleanup } from '@testing-library/react';
import '@testing-library/jest-dom/vitest';
import { server } from '../mocks/node';
import { MotionGlobalConfig } from 'motion/react';

// Tests assert on end states; an exit animation only adds flake.
MotionGlobalConfig.skipAnimations = true;

/**
 * Test setup.
 *
 * MSW intercepts every request the app makes, so component tests exercise the
 * same handlers the running app uses — no per-test stubbing of the service
 * layer. Testing Library's DOM is torn down between tests.
 *
 * jsdom does not implement these, and Radix's popovers/scroll areas call them
 * on mount, so they are stubbed once here rather than in every test.
 */
beforeAll(() => {
  server.listen({ onUnhandledRequest: 'warn' });

  if (!window.matchMedia) {
    window.matchMedia = ((query: string) => ({
      matches: false,
      media: query,
      onchange: null,
      addEventListener: () => {},
      removeEventListener: () => {},
      addListener: () => {},
      removeListener: () => {},
      dispatchEvent: () => false,
    })) as typeof window.matchMedia;
  }

  if (!window.ResizeObserver) {
    window.ResizeObserver = class {
      observe() {}
      unobserve() {}
      disconnect() {}
    } as unknown as typeof ResizeObserver;
  }

  // TanStack Router restores scroll on every navigation; jsdom has no layout,
  // so the call is meaningless here but noisy if left unstubbed.
  window.scrollTo = () => {};

  if (!Element.prototype.scrollIntoView) {
    Element.prototype.scrollIntoView = () => {};
  }
  if (!Element.prototype.hasPointerCapture) {
    Element.prototype.hasPointerCapture = () => false;
  }
  if (!Element.prototype.releasePointerCapture) {
    Element.prototype.releasePointerCapture = () => {};
  }

  // jsdom has no WebGL or 2D canvas backend — `getContext` exists but logs a
  // "not implemented" error and returns undefined. The settings window's mini
  // orb (`OrbCanvas`) calls it every animation frame, so it is stubbed to
  // return null (its documented "unsupported" value) to keep test output
  // pristine.
  HTMLCanvasElement.prototype.getContext = (() => null) as typeof HTMLCanvasElement.prototype.getContext;

  // jsdom has no Font Loading API; Mantine's autosizing Textarea listens for
  // `loadingdone` on it to re-measure once web fonts settle.
  if (!document.fonts) {
    Object.defineProperty(document, 'fonts', {
      value: {
        addEventListener: () => {},
        removeEventListener: () => {},
      },
      configurable: true,
    });
  }
});

afterEach(() => {
  cleanup();
  server.resetHandlers();
});

afterAll(() => {
  server.close();
});

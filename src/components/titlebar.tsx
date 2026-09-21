import { Box, Text } from '@mantine/core';

import { isElectron, isMac, TRAFFIC_LIGHT_INSET } from '@/lib/platform';

/**
 * Native window chrome.
 *
 * The BrowserWindow is frameless (`titleBarStyle: 'hiddenInset'` on macOS), so
 * the app has to supply its own drag region or the window can't be moved. This
 * strip is that region: it reserves room for the traffic lights on the left and
 * marks itself `app-region-drag`. That class stays a class on purpose —
 * `-webkit-app-region` is not a property any Mantine style prop or theme value
 * reaches, so `src/App.css` is the only place it can live. Any control placed
 * inside the strip must opt out with `app-region-no-drag`, or it will move the
 * window instead of being clicked.
 *
 * In a plain browser tab (`vite dev` without Electron) it renders nothing — the
 * OS already drew a title bar there.
 *
 * The surface is one step below the page rather than a tint of a sidebar token:
 * this strip sits above every scheme, and `light-dark()` picks per scheme from
 * the same ramp the rest of the chrome reads.
 */
export function Titlebar({ title }: { title?: string }) {
  if (!isElectron) return null;

  return (
    <Box
      px="xs"
      h={36}
      className="app-region-drag"
      style={{
        display: 'flex',
        alignItems: 'center',
        flexShrink: 0,
        borderBottom: '1px solid var(--mantine-color-default-border)',
        background: 'light-dark(var(--mantine-color-gray-0), var(--mantine-color-dark-9))',
        paddingLeft: TRAFFIC_LIGHT_INSET || undefined,
      }}
    >
      <Text size="xs" fw={500} c="dimmed" truncate>
        {title}
      </Text>
      {!isMac && <Box style={{ marginLeft: 'auto' }} />}
    </Box>
  );
}

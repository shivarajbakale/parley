/**
 * The tray menu as a pure template, so its wording and wiring are testable.
 * `main.ts` hands the result to `Menu.buildFromTemplate`.
 */

export interface TrayState {
  ready: boolean;
  lastTranscript: string | null;
}

export interface TrayActions {
  copyLast(): void;
  openSettings(): void;
  quit(): void;
}

export interface TrayItem {
  label?: string;
  type?: 'separator';
  enabled?: boolean;
  click?: () => void;
}

export function trayMenuTemplate(state: TrayState, actions: TrayActions): TrayItem[] {
  return [
    { label: state.ready ? 'Parley is ready' : 'Setup needed — open Settings', enabled: false },
    { type: 'separator' },
    {
      label: 'Copy last transcript',
      enabled: state.lastTranscript !== null,
      click: actions.copyLast,
    },
    { label: 'Settings…', click: actions.openSettings },
    { type: 'separator' },
    { label: 'Quit Parley', click: actions.quit },
  ];
}

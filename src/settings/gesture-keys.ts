import type { GestureKey } from '../../electron/types';

/** Human labels for the eight modifier gesture keys. Shared by the Gesture tab
 * and the wizard's hotkey step. Lives here because a component file may only
 * export components (react-refresh). */
export const KEY_LABELS: Record<GestureKey, string> = {
  AltRight: 'Right Option',
  Alt: 'Left Option',
  CtrlRight: 'Right Control',
  Ctrl: 'Left Control',
  ShiftRight: 'Right Shift',
  Shift: 'Left Shift',
  MetaRight: 'Right Command',
  Meta: 'Left Command',
};

/** The key-cap glyph for each gesture key, as printed on a Mac keyboard. */
export const KEY_GLYPHS: Record<GestureKey, string> = {
  AltRight: '⌥',
  Alt: '⌥',
  CtrlRight: '⌃',
  Ctrl: '⌃',
  ShiftRight: '⇧',
  Shift: '⇧',
  MetaRight: '⌘',
  Meta: '⌘',
};

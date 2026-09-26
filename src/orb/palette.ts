/**
 * The orb's colours come from theme tokens, never literals. Tokens are
 * `oklch()` strings, which a shader cannot use, so each one is painted onto a
 * 1 px canvas and read back as sRGB bytes, then converted to the linear floats
 * the shader blends in.
 */
export type Rgb = [number, number, number];

export interface OrbPalette {
  aurora: [Rgb, Rgb, Rgb];
  /** The same three depths in amber, worn while a voice edit is running. */
  edit: [Rgb, Rgb, Rgb];
  /** The same three depths in cyan, worn while Explain is listening. */
  explain: [Rgb, Rgb, Rgb];
  /** The same three depths in rose, worn while the agent is working. */
  act: [Rgb, Rgb, Rgb];
  done: Rgb;
  error: Rgb;
}

export const PALETTE_TOKENS = {
  aurora: ['--app-aurora-deep', '--app-aurora-core', '--app-aurora-glow'],
  done: '--mantine-color-teal-5',
  error: '--mantine-color-red-6',
  edit: ['--app-edit-deep', '--app-edit-core', '--app-edit-glow'],
  explain: ['--app-explain-deep', '--app-explain-core', '--app-explain-glow'],
  act: ['--app-act-deep', '--app-act-core', '--app-act-glow'],
} as const;

export function srgbByteToLinear(byte: number): number {
  const channel = byte / 255;
  return channel <= 0.04045 ? channel / 12.92 : ((channel + 0.055) / 1.055) ** 2.4;
}

const toLinear = ([r, g, b]: Rgb): Rgb => [
  srgbByteToLinear(r),
  srgbByteToLinear(g),
  srgbByteToLinear(b),
];

export function buildPalette(readBytes: (token: string) => Rgb): OrbPalette {
  const [deep, core, glow] = PALETTE_TOKENS.aurora.map((token) => toLinear(readBytes(token)));
  const done = toLinear(readBytes(PALETTE_TOKENS.done));
  const error = toLinear(readBytes(PALETTE_TOKENS.error));
  const triple = (tokens: readonly [string, string, string]): [Rgb, Rgb, Rgb] => {
    const [a, b, c] = tokens.map((token) => toLinear(readBytes(token)));
    return [a, b, c];
  };
  return {
    aurora: [deep, core, glow],
    edit: triple(PALETTE_TOKENS.edit),
    explain: triple(PALETTE_TOKENS.explain),
    act: triple(PALETTE_TOKENS.act),
    done,
    error,
  };
}

/** Browser only: resolves a CSS custom property to sRGB bytes. */
export function readTokenBytes(token: string): Rgb {
  const value = getComputedStyle(document.documentElement).getPropertyValue(token).trim();
  const canvas = document.createElement('canvas');
  canvas.width = canvas.height = 1;
  const context = canvas.getContext('2d', { willReadFrequently: true });
  if (!context || !value) return [255, 255, 255];
  context.fillStyle = value;
  context.fillRect(0, 0, 1, 1);
  const [r, g, b] = context.getImageData(0, 0, 1, 1).data;
  return [r, g, b];
}

/**
 * Time saved by dictating instead of typing, as a plain estimate: an average
 * typist manages about 40 words a minute, and people speak at about 150.
 * Only pasted dictation is counted, since that is what replaces typing.
 */
export const TYPING_WPM = 40;
export const SPEAKING_WPM = 150;

export function minutesSaved(words: number): number {
  if (!Number.isFinite(words) || words <= 0) return 0;
  return words / TYPING_WPM - words / SPEAKING_WPM;
}

/** “Under a minute”, “26 min”, “3 h 5 min”. */
export function formatSaved(minutes: number): string {
  if (minutes < 1) return 'Under a minute';
  const whole = Math.round(minutes);
  if (whole < 60) return `${whole} min`;
  const hours = Math.floor(whole / 60);
  const rest = whole % 60;
  return rest === 0 ? `${hours} h` : `${hours} h ${rest} min`;
}

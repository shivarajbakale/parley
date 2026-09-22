import { render, screen } from '@testing-library/react';
import { describe, expect, it } from 'vitest';

import { ThemeProvider } from '@/components/theme-provider';

import { OrbProgress } from '../wizard/OrbProgress';

function renderRing(step: number, label: string) {
  render(
    <ThemeProvider>
      <OrbProgress step={step} total={6} label={label} />
    </ThemeProvider>
  );
  return screen.getByRole('progressbar', { name: 'Setup progress' });
}

describe('OrbProgress', () => {
  it('speaks the step and its name, since the ring prints no number', () => {
    const ring = renderRing(1, 'Accessibility');
    expect(ring).toHaveAttribute('aria-valuetext', 'Step 2 of 6: Accessibility');
    expect(ring).toHaveAttribute('aria-valuenow', '1');
    expect(ring).toHaveAttribute('aria-valuemax', '6');
    expect(screen.queryByText(/Step 2 of 6/)).not.toBeInTheDocument();
  });

  it('reads as complete once every step is done', () => {
    const ring = renderRing(6, 'Done');
    expect(ring).toHaveAttribute('aria-valuetext', 'Setup complete');
    expect(ring).toHaveAttribute('aria-valuenow', '6');
  });
});

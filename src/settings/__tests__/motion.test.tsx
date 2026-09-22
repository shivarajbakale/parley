import { render, screen } from '@testing-library/react';
import { describe, expect, it } from 'vitest';

import { StaggerGroup, StaggerItem } from '../motion';
import { tabDirection } from '../motion-variants';

describe('tabDirection', () => {
  it('is 1 moving down the rail and -1 moving up', () => {
    expect(tabDirection('overview', 'general')).toBe(1);
    expect(tabDirection('general', 'gesture')).toBe(-1);
  });
});

describe('StaggerGroup', () => {
  it('renders its children', () => {
    render(
      <StaggerGroup>
        <StaggerItem>first</StaggerItem>
        <StaggerItem>second</StaggerItem>
      </StaggerGroup>
    );
    expect(screen.getByText('first')).toBeInTheDocument();
    expect(screen.getByText('second')).toBeInTheDocument();
  });
});

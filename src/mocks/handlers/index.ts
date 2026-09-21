/**
 * MSW handler registry.
 *
 * Add one handler array per resource. The `add-api-endpoint` and `add-feature`
 * skills append here automatically.
 */
import { projectHandlers } from './projectHandlers';

export const handlers = [
  ...projectHandlers,
  // ...add your resource handlers here
];

export { projectHandlers } from './projectHandlers';

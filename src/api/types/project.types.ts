/**
 * Project domain types — the reference resource.
 *
 * This is the shape shared end-to-end: MSW handler → service → query hooks →
 * pages. Copy this file (and its siblings in the slice) when adding a new
 * resource; the `add-feature` skill automates the whole vertical.
 */

export type ProjectStatus = 'active' | 'paused' | 'archived';

export interface Project {
  id: string;
  name: string;
  description: string;
  status: ProjectStatus;
  /** Completion percentage, 0–100. */
  progress: number;
  createdAt: string;
  updatedAt: string;
}

export interface CreateProjectDto {
  name: string;
  description?: string;
  status?: ProjectStatus;
}

export type UpdateProjectDto = Partial<CreateProjectDto> & {
  progress?: number;
};

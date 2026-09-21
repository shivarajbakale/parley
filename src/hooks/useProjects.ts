/**
 * Project query & mutation hooks (TanStack Query).
 *
 * Components use these — not the service or axios — so caching, refetching, and
 * invalidation are handled in one place. `projectKeys` keeps query keys
 * consistent between reads and invalidations.
 */
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { toast } from '@/lib/notify';
import { projectService } from '@/api/services/projectService';
import type { CreateProjectDto, UpdateProjectDto } from '@/api/types';

export const projectKeys = {
  all: ['projects'] as const,
  list: () => [...projectKeys.all, 'list'] as const,
  detail: (id: string) => [...projectKeys.all, 'detail', id] as const,
};

export function useProjects() {
  return useQuery({
    queryKey: projectKeys.list(),
    queryFn: () => projectService.list(),
  });
}

export function useProject(id: string) {
  return useQuery({
    queryKey: projectKeys.detail(id),
    queryFn: () => projectService.get(id),
    enabled: Boolean(id),
  });
}

export function useCreateProject() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (data: CreateProjectDto) => projectService.create(data),
    onSuccess: (project) => {
      qc.invalidateQueries({ queryKey: projectKeys.all });
      toast.success(`Project “${project.name}” created`);
    },
    onError: () => toast.error('Could not create project'),
  });
}

export function useUpdateProject(id: string) {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (data: UpdateProjectDto) => projectService.update(id, data),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: projectKeys.all });
      toast.success('Project updated');
    },
    onError: () => toast.error('Could not update project'),
  });
}

export function useDeleteProject() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (id: string) => projectService.remove(id),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: projectKeys.all });
      toast.success('Project deleted');
    },
    onError: () => toast.error('Could not delete project'),
  });
}

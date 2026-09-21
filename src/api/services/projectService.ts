/**
 * Project API service.
 *
 * The single place that knows the project HTTP endpoints. Methods return the
 * unwrapped domain type (via `extractData`). Query hooks call these — components
 * never call the service directly.
 */
import apiClient, { extractData } from '../client';
import type { ApiResponse, Project, CreateProjectDto, UpdateProjectDto } from '../types';

export const projectService = {
  async list(): Promise<Project[]> {
    const res = await apiClient.get<ApiResponse<Project[]>>('/projects');
    return extractData(res);
  },

  async get(id: string): Promise<Project> {
    const res = await apiClient.get<ApiResponse<Project>>(`/projects/${id}`);
    return extractData(res);
  },

  async create(data: CreateProjectDto): Promise<Project> {
    const res = await apiClient.post<ApiResponse<Project>>('/projects', data);
    return extractData(res);
  },

  async update(id: string, data: UpdateProjectDto): Promise<Project> {
    const res = await apiClient.patch<ApiResponse<Project>>(`/projects/${id}`, data);
    return extractData(res);
  },

  async remove(id: string): Promise<void> {
    await apiClient.delete(`/projects/${id}`);
  },
};

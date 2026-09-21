/**
 * MSW handlers for the Projects resource.
 *
 * Lets the frontend run with no backend: `VITE_ENABLE_MOCKING=true` routes
 * `/api/projects*` here. State is in-memory (resets on reload). When your real
 * API is ready, delete this file from the handler list — the service/hooks/pages
 * are unchanged.
 */
import { http, HttpResponse } from 'msw';
import type { Project, ProjectStatus, CreateProjectDto, UpdateProjectDto } from '@/api/types';

const NAMES = [
  'Billing v2',
  'API Gateway',
  'Design System',
  'Mobile Onboarding',
  'Data Pipeline',
  'Search Revamp',
  'Notifications',
  'Analytics Dashboard',
  'Auth Service',
  'Marketing Site',
  'Admin Console',
  'Realtime Sync',
];
const STATUSES: ProjectStatus[] = ['active', 'active', 'active', 'paused', 'archived'];

function uuid(): string {
  return typeof crypto !== 'undefined' && crypto.randomUUID
    ? crypto.randomUUID()
    : 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, (c) => {
        const r = (Math.random() * 16) | 0;
        return (c === 'x' ? r : (r & 0x3) | 0x8).toString(16);
      });
}

function seed(): Project[] {
  const now = Date.now();
  return NAMES.map((name, i) => ({
    id: uuid(),
    name,
    description: `Everything related to ${name.toLowerCase()}.`,
    status: STATUSES[i % STATUSES.length],
    progress: (i * 17) % 101,
    createdAt: new Date(now - (i + 1) * 86_400_000).toISOString(),
    updatedAt: new Date(now - i * 3_600_000).toISOString(),
  }));
}

let projects: Project[] = seed();

const ok = <T>(data: T, status = 200) => HttpResponse.json({ success: true, data }, { status });
const notFound = () =>
  HttpResponse.json({ success: false, message: 'Project not found' }, { status: 404 });

export const projectHandlers = [
  http.get('/api/projects', () => ok(projects)),

  http.get('/api/projects/:id', ({ params }) => {
    const project = projects.find((p) => p.id === params.id);
    return project ? ok(project) : notFound();
  }),

  http.post('/api/projects', async ({ request }) => {
    const body = (await request.json()) as CreateProjectDto;
    const iso = new Date().toISOString();
    const project: Project = {
      id: uuid(),
      name: body.name,
      description: body.description ?? '',
      status: body.status ?? 'active',
      progress: 0,
      createdAt: iso,
      updatedAt: iso,
    };
    projects = [project, ...projects];
    return ok(project, 201);
  }),

  http.patch('/api/projects/:id', async ({ params, request }) => {
    const body = (await request.json()) as UpdateProjectDto;
    const idx = projects.findIndex((p) => p.id === params.id);
    if (idx === -1) return notFound();
    projects[idx] = { ...projects[idx], ...body, updatedAt: new Date().toISOString() };
    return ok(projects[idx]);
  }),

  http.delete('/api/projects/:id', ({ params }) => {
    const existed = projects.some((p) => p.id === params.id);
    if (!existed) return notFound();
    projects = projects.filter((p) => p.id !== params.id);
    return new HttpResponse(null, { status: 204 });
  }),
];

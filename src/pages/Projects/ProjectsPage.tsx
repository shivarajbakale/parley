import * as React from 'react';
import { useNavigate, useParams } from '@tanstack/react-router';
import { FolderKanban, MousePointerClick, Plus } from 'lucide-react';

import type { Project } from '@/api/types';
import { useProjects } from '@/hooks/useProjects';
import { useIsMobile } from '@/hooks/use-mobile';
import { PageShell } from '@/components/page-shell';
import { projectColumns } from '@/pages/Projects/project-columns';
import { ProjectDetailPane } from '@/pages/Projects/ProjectDetailPane';
import { ProjectForm } from '@/pages/Projects/project-form';
import { Box, Button, Drawer, EmptyState, Modal, Paper, Splitter } from '@mantine/core';

import { DataTable } from '@/components/data-table';

/**
 * Projects — the reference slice, as a master-detail view.
 *
 * One route component serves both `/projects` and `/projects/$projectId`: the
 * list stays mounted on the left and the selected project fills the right pane,
 * so selecting a row never navigates the user away from their place in the list.
 * The URL still carries the selection, so detail views remain shareable and the
 * back button behaves.
 *
 * On small screens the two panes cannot coexist, so the detail becomes a Sheet.
 */
export function ProjectsPage() {
  const navigate = useNavigate();
  const isMobile = useIsMobile();
  const { projectId } = useParams({ strict: false }) as { projectId?: string };
  const { data: projects, isLoading, isError } = useProjects();
  const [createOpen, setCreateOpen] = React.useState(false);

  const select = (project: Project) =>
    navigate({ to: '/projects/$projectId', params: { projectId: project.id } });

  const clearSelection = () => navigate({ to: '/projects' });

  const list = (
    <DataTable
      columns={projectColumns}
      data={projects ?? []}
      getRowId={(p) => p.id}
      isLoading={isLoading}
      onRowClick={select}
      selectedRowId={projectId ?? null}
      filterPlaceholder="Filter projects…"
      empty={
        isError ? (
          <EmptyState
            icon={<FolderKanban size={20} />}
            title="Couldn’t load projects"
            description="The request failed. Check the console, then try again."
          />
        ) : (
          <EmptyState
            icon={<FolderKanban size={20} />}
            title="No projects yet"
            description="Create your first project to get started."
          >
            <Button size="sm" leftSection={<Plus size={16} />} onClick={() => setCreateOpen(true)}>
              New project
            </Button>
          </EmptyState>
        )
      }
    />
  );

  return (
    <PageShell
      title="Projects"
      description="Everything your team is building."
      archetype="list-detail"
      scroll={false}
      bodyProps={{ px: 'lg', pb: 'lg' }}
      actions={
        <>
          <Button leftSection={<Plus size={16} />} onClick={() => setCreateOpen(true)}>
            New project
          </Button>
          <Modal
            opened={createOpen}
            onClose={() => setCreateOpen(false)}
            title="New project"
            size="lg"
            centered
          >
            <ProjectForm
              onCancel={() => setCreateOpen(false)}
              onCreated={(id) => {
                setCreateOpen(false);
                navigate({ to: '/projects/$projectId', params: { projectId: id } });
              }}
            />
          </Modal>
        </>
      }
    >
      {isMobile ? (
        <>
          <Paper withBorder radius="md" p={0} h="100%" style={{ overflow: 'hidden' }}>
            {list}
          </Paper>
          <Drawer
            opened={Boolean(projectId)}
            onClose={clearSelection}
            position="right"
            size="md"
            padding={0}
            title="Project detail"
            styles={{ title: { position: 'absolute', width: 1, height: 1, overflow: 'hidden', clip: 'rect(0 0 0 0)' } }}
          >
            {projectId && <ProjectDetailPane projectId={projectId} onDeleted={clearSelection} />}
          </Drawer>
        </>
      ) : (
        // A `Box`, not a `Paper`, and that is the whole reason.
        // `theme.components.Paper` sets `data-panel="card"` as a default prop so
        // the probe sees every surface without each screen opting in — but this
        // frame must NOT be a panel: each pane inside carries its own
        // `data-panel`, and the probe measures the outermost one it finds, so a
        // panel here shadows both panes and the list-detail rule counts one.
        // Passing `data-panel={undefined}` does not help: Mantine's merge reads
        // an explicit `undefined` as "not passed" and reinstates the default.
        // B1 failed at all three viewports until this stopped being a Paper.
        <Box
          h="100%"
          style={{
            overflow: 'hidden',
            border: '1px solid var(--mantine-color-default-border)',
            borderRadius: 'var(--mantine-radius-md)',
          }}
        >
          <Splitter style={{ height: '100%' }}>
            <Splitter.Pane data-panel="list" defaultSize={55} min={32}>
              {list}
            </Splitter.Pane>
            <Splitter.Pane data-panel="detail" defaultSize={45} min={28}>
              {projectId ? (
                <ProjectDetailPane
                  projectId={projectId}
                  onClose={clearSelection}
                  onDeleted={clearSelection}
                />
              ) : (
                <EmptyState
                  icon={<MousePointerClick size={20} />}
                  title="Nothing selected"
                  description="Pick a project on the left to see its detail here."
                />
              )}
            </Splitter.Pane>
          </Splitter>
        </Box>
      )}
    </PageShell>
  );
}

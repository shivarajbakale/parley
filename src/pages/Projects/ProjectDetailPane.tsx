import { Minus, PanelRightClose, Plus, Trash2 } from 'lucide-react';
import {
  ActionIcon,
  Box,
  Button,
  Center,
  DataList,
  Group,
  Paper,
  Progress,
  ScrollArea,
  Skeleton,
  Stack,
  Tabs,
  Text,
  Title,
} from '@mantine/core';
import { modals } from '@mantine/modals';

import { useProject, useUpdateProject, useDeleteProject } from '@/hooks/useProjects';
import { StatusBadge } from '@/pages/Projects/StatusBadge';

/**
 * Right-hand pane of the Projects master-detail view.
 *
 * It owns its own scroll region — the header stays pinned while the body moves —
 * so opening a project never scrolls the list out from under the user.
 */
export function ProjectDetailPane({
  projectId,
  onClose,
  onDeleted,
}: {
  projectId: string;
  onClose?: () => void;
  onDeleted?: () => void;
}) {
  const { data: project, isLoading, isError } = useProject(projectId);
  const update = useUpdateProject(projectId);
  const remove = useDeleteProject();

  if (isLoading) {
    return (
      <Stack gap="md" p="lg">
        <Skeleton height={28} width={208} />
        <Skeleton height={16} />
        <Skeleton height={112} />
      </Stack>
    );
  }

  if (isError || !project) {
    return (
      <Center p="lg" h="100%" w="100%" ta="center">
        <Box>
          <Text size="sm" fw={500}>
            Project not found
          </Text>
          <Text size="sm" c="dimmed" mt={4}>
            It may have been deleted. Pick another from the list.
          </Text>
        </Box>
      </Center>
    );
  }

  const setProgress = (delta: number) =>
    update.mutate({ progress: Math.max(0, Math.min(100, project.progress + delta)) });

  const confirmDelete = () =>
    modals.openConfirmModal({
      title: 'Delete this project?',
      children: (
        <Text size="sm">
          “{project.name}” will be permanently removed. This can’t be undone.
        </Text>
      ),
      labels: { confirm: 'Delete', cancel: 'Cancel' },
      confirmProps: { color: 'red' },
      onConfirm: () => remove.mutate(project.id, { onSuccess: () => onDeleted?.() }),
    });

  return (
    <Stack gap={0} h="100%" style={{ minHeight: 0 }}>
      <Group
        component="header"
        align="flex-start"
        justify="space-between"
        gap="sm"
        px="lg"
        py="md"
        style={{
          flexShrink: 0,
          borderBottom: '1px solid var(--mantine-color-default-border)',
        }}
      >
        <Stack gap={6} style={{ minWidth: 0 }}>
          <Group gap="xs" wrap="nowrap">
            {/* `Title` has no `truncate` — that is `Text`'s prop. The three
                declarations below are what it expands to, and the pane is
                resizable, so a long project name has to end in an ellipsis
                rather than push the status badge out of the header. */}
            <Title
              order={2}
              size="h5"
              style={{
                minWidth: 0,
                overflow: 'hidden',
                textOverflow: 'ellipsis',
                whiteSpace: 'nowrap',
              }}
            >
              {project.name}
            </Title>
            <StatusBadge status={project.status} />
          </Group>
          <Text size="sm" c="dimmed" lineClamp={2}>
            {project.description}
          </Text>
        </Stack>

        <Group gap={4} wrap="nowrap" style={{ flexShrink: 0 }}>
          {/* `modals.openConfirmModal` rather than a dialog assembled here: the
              confirm/cancel order, the focus trap and the escape behaviour are
              decisions that must not differ between two delete buttons. */}
          <ActionIcon
            variant="subtle"
            color="gray"
            aria-label="Delete project"
            onClick={confirmDelete}
          >
            <Trash2 size={16} />
          </ActionIcon>

          {onClose && (
            <ActionIcon variant="subtle" color="gray" aria-label="Close panel" onClick={onClose}>
              <PanelRightClose size={16} />
            </ActionIcon>
          )}
        </Group>
      </Group>

      <ScrollArea style={{ minHeight: 0, flex: 1 }}>
        <Box p="lg">
          <Tabs defaultValue="overview">
            <Tabs.List>
              <Tabs.Tab value="overview">Overview</Tabs.Tab>
              <Tabs.Tab value="details">Details</Tabs.Tab>
            </Tabs.List>

            <Tabs.Panel value="overview" pt="md">
              <Paper withBorder radius="md" p="md">
                <Group justify="space-between">
                  <Text component="h3" size="sm" fw={500}>
                    Progress
                  </Text>
                  <Text size="sm" c="dimmed" style={{ fontVariantNumeric: 'tabular-nums' }}>
                    {project.progress}%
                  </Text>
                </Group>
                <Progress value={project.progress} size="md" mt="sm" />
                <Group gap="xs" mt="sm">
                  <Button
                    variant="default"
                    size="xs"
                    leftSection={<Minus size={16} />}
                    onClick={() => setProgress(-10)}
                    disabled={update.isPending}
                  >
                    10%
                  </Button>
                  <Button
                    variant="default"
                    size="xs"
                    leftSection={<Plus size={16} />}
                    onClick={() => setProgress(10)}
                    disabled={update.isPending}
                  >
                    10%
                  </Button>
                </Group>
              </Paper>
            </Tabs.Panel>

            <Tabs.Panel value="details" pt="md">
              {/* `DataList` is the definition list this page used to build out
                  of a 1px-gap grid and a local `Meta` helper — same shape, one
                  component, and the divider is the theme's. */}
              <DataList withDivider labelWidth={120}>
                <DataList.Item>
                  <DataList.ItemLabel>Created</DataList.ItemLabel>
                  <DataList.ItemValue>
                    {new Date(project.createdAt).toLocaleDateString()}
                  </DataList.ItemValue>
                </DataList.Item>
                <DataList.Item>
                  <DataList.ItemLabel>Last updated</DataList.ItemLabel>
                  <DataList.ItemValue>
                    {new Date(project.updatedAt).toLocaleString()}
                  </DataList.ItemValue>
                </DataList.Item>
                <DataList.Item>
                  <DataList.ItemLabel>Status</DataList.ItemLabel>
                  <DataList.ItemValue tt="capitalize">{project.status}</DataList.ItemValue>
                </DataList.Item>
                <DataList.Item>
                  <DataList.ItemLabel>ID</DataList.ItemLabel>
                  <DataList.ItemValue ff="monospace" fz="xs">
                    {project.id.slice(0, 8)}
                  </DataList.ItemValue>
                </DataList.Item>
              </DataList>
            </Tabs.Panel>
          </Tabs>
        </Box>
      </ScrollArea>
    </Stack>
  );
}

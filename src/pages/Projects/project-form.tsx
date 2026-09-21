import { Controller, useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import {
  Button,
  Group,
  Input,
  SegmentedControl,
  Stack,
  Textarea,
  TextInput,
} from '@mantine/core';

import type { ProjectStatus } from '@/api/types';
import { useCreateProject } from '@/hooks/useProjects';

/**
 * Create-project form.
 *
 * Mantine's inputs own their label, description and error slot, so a field is
 * one component and the error is wired to the control by `aria-describedby`
 * without the page arranging it. Copy this shape for any new resource form —
 * never hand-roll an input, a textarea or a segmented control.
 *
 * `Controller`, not `register()`: these are controlled components rather than
 * registerable refs, and `SegmentedControl` has no ref to give.
 */
const schema = z.object({
  name: z.string().min(2, 'Give your project a name'),
  description: z.string().max(280, 'Keep it under 280 characters').optional(),
  status: z.enum(['active', 'paused', 'archived']),
});

type FormValues = z.infer<typeof schema>;

const statuses: ProjectStatus[] = ['active', 'paused', 'archived'];

export function ProjectForm({
  onCreated,
  onCancel,
}: {
  onCreated?: (id: string) => void;
  onCancel?: () => void;
}) {
  const create = useCreateProject();

  const { control, handleSubmit, reset } = useForm<FormValues>({
    resolver: zodResolver(schema),
    defaultValues: { name: '', description: '', status: 'active' },
  });

  const onSubmit = (values: FormValues) =>
    create.mutate(values, {
      onSuccess: (project) => {
        reset();
        onCreated?.(project.id);
      },
    });

  return (
    <form onSubmit={handleSubmit(onSubmit)}>
      <Stack gap="md">
        <Controller
          control={control}
          name="name"
          render={({ field, fieldState }) => (
            <TextInput
              label="Name"
              placeholder="e.g. Billing v2"
              // `data-autofocus`, not `autoFocus`: Mantine's focus trap runs
              // after the Modal's open transition and parks focus on the close
              // button, so the attribute the trap looks for is the only one
              // that survives — and a create dialog should take the first
              // keystroke of someone who starts typing straight away.
              data-autofocus
              error={fieldState.error?.message}
              {...field}
            />
          )}
        />

        <Controller
          control={control}
          name="description"
          render={({ field, fieldState }) => (
            <Textarea
              label="Description"
              rows={3}
              placeholder="What is this project about?"
              description="Optional. Shown beneath the name in the list."
              error={fieldState.error?.message}
              {...field}
            />
          )}
        />

        <Controller
          control={control}
          name="status"
          render={({ field }) => (
            <Input.Wrapper label="Status">
              <div>
                <SegmentedControl
                  value={field.value}
                  onChange={field.onChange}
                  data={statuses.map((s) => ({
                    value: s,
                    label: s[0].toUpperCase() + s.slice(1),
                  }))}
                />
              </div>
            </Input.Wrapper>
          )}
        />

        <Group justify="flex-end" gap="xs" pt={4}>
          {onCancel && (
            <Button type="button" variant="subtle" color="gray" onClick={onCancel}>
              Cancel
            </Button>
          )}
          <Button type="submit" loading={create.isPending}>
            Create project
          </Button>
        </Group>
      </Stack>
    </form>
  );
}

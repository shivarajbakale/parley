import { Alert, Box, ColorSwatch, Group, Modal, Stack, Text } from '@mantine/core';
import { useEffect, useRef } from 'react';

import { ApiKeySection } from './SetupTab';
import { useSetRewriteKey } from './use-parley';

/** How long the ‘try again’ line shows before the offer closes itself. */
const CLOSE_AFTER_MS = 1600;

const MODES = [
  { name: 'Voice edit', color: 'var(--app-edit-core)', copy: 'rewrites the text in a field.' },
  { name: 'Explain', color: 'var(--app-explain-core)', copy: 'answers a question about a selection.' },
];

/**
 * MiniMax is asked for at the moment it is first needed, not during setup:
 * the first voice edit or Explain gesture with no key opens this over
 * whatever the settings window is showing.
 */
export function MiniMaxOffer({
  opened,
  hasRewriteKey,
  onClose,
  withinPortal = true,
}: {
  opened: boolean;
  hasRewriteKey: boolean;
  onClose(): void;
  /** Stories render it in place, so the probe can measure it inside the story root. */
  withinPortal?: boolean;
}) {
  const setRewriteKey = useSetRewriteKey();
  const stored = opened && hasRewriteKey;
  const onCloseRef = useRef(onClose);
  onCloseRef.current = onClose;

  useEffect(() => {
    if (!stored) return;
    const timer = setTimeout(() => onCloseRef.current(), CLOSE_AFTER_MS);
    return () => clearTimeout(timer);
  }, [stored]);

  return (
    <Modal
      opened={opened}
      onClose={onClose}
      title="Voice edit and Explain need MiniMax"
      centered
      withinPortal={withinPortal}
    >
      <Stack gap="md" pt="xs">
        <Stack gap="xs">
          {MODES.map(mode => (
            <Group key={mode.name} gap="sm" wrap="nowrap">
              <ColorSwatch color={mode.color} size={12} withShadow={false} />
              <Text size="sm">
                <Text span fw={600}>
                  {mode.name}
                </Text>{' '}
                {mode.copy}
              </Text>
            </Group>
          ))}
        </Stack>
        <Text size="sm" c="dimmed">
          Both send your words to MiniMax. Dictation keeps working without it.
        </Text>
        {stored ? (
          <Alert color="teal" variant="light" title="MiniMax is set up">
            Try the gesture again.
          </Alert>
        ) : (
          <Box>
            <ApiKeySection
              label="MiniMax API key"
              placeholder="Paste your key"
              purpose="Used only for voice edit and Explain."
              submitLabel="Test and save MiniMax key"
              hasApiKey={hasRewriteKey}
              setApiKey={setRewriteKey}
            />
          </Box>
        )}
      </Stack>
    </Modal>
  );
}

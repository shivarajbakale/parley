import { Box, Text } from '@mantine/core';
import { AnimatePresence, motion } from 'motion/react';

import type { OrbNotice } from './phase-handler';
import classes from './Notice.module.css';

/** Looser than the app's `SPRING` on purpose: it matches the bounce the canvas pill opens with. */
const POP = { type: 'spring', stiffness: 320, damping: 20 } as const;

/** The pill with words in it: an offer to remember a word, and the thanks for a yes. */
export function Notice({ notice }: { notice: OrbNotice | null }) {
  return (
    <AnimatePresence>
      {notice && (
        <motion.div
          key={notice.accepted ? 'accepted' : 'offer'}
          initial={{ scale: 0.1, opacity: 0 }}
          animate={{ scale: 1, opacity: 1 }}
          exit={{ scale: 0.1, opacity: 0, transition: { duration: 0.15 } }}
          transition={POP}
        >
          <Box className={classes.notice} data-accepted={notice.accepted} role="status">
            <Text size="sm" fw={600} c="white" lh={1.25}>
              {notice.message}
            </Text>
            {notice.hint && (
              <Text size="xs" c="dimmed" lh={1.25}>
                {notice.hint}
              </Text>
            )}
          </Box>
        </motion.div>
      )}
    </AnimatePresence>
  );
}

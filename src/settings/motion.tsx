/* eslint-disable react-refresh/only-export-components -- this module also exports
   tabDirection and panelVariants, plain helpers the shell and panels both need; splitting
   them into their own file just to satisfy fast-refresh would separate them from the
   components that exist to consume the same motion values. */
import { motion } from 'motion/react';
import type { ReactNode } from 'react';

import { DURATION, EASE, SPRING, STAGGER } from '@/lib/motion';

import { TAB_ORDER, type TabId } from './tabs';

/** 1 when the new tab is further down the rail, so content slides up to meet it. */
export function tabDirection(from: TabId, to: TabId): 1 | -1 {
  return TAB_ORDER.indexOf(to) >= TAB_ORDER.indexOf(from) ? 1 : -1;
}

/** Tab content: crossfade with an 8 px slide in the direction of travel. */
export const panelVariants = {
  enter: (direction: number) => ({ opacity: 0, y: 8 * direction }),
  center: { opacity: 1, y: 0, transition: { duration: DURATION.base, ease: EASE } },
  exit: (direction: number) => ({
    opacity: 0,
    y: -8 * direction,
    transition: { duration: DURATION.fast, ease: EASE },
  }),
};

const group = { center: { transition: { staggerChildren: STAGGER } } };
const item = {
  enter: { opacity: 0, y: 6 },
  center: { opacity: 1, y: 0, transition: SPRING },
};

export function StaggerGroup({ children }: { children: ReactNode }) {
  return (
    <motion.div variants={group} initial="enter" animate="center">
      {children}
    </motion.div>
  );
}

export function StaggerItem({ children }: { children: ReactNode }) {
  return <motion.div variants={item}>{children}</motion.div>;
}

/** Spring press for anything tappable. Wraps, so Mantine's own element is untouched. */
export function Pressable({ children }: { children: ReactNode }) {
  return (
    <motion.span style={{ display: 'inline-block' }} whileTap={{ scale: 0.97 }} transition={SPRING}>
      {children}
    </motion.span>
  );
}

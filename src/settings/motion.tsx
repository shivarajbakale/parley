import { motion } from 'motion/react';
import type { ReactNode } from 'react';

import { SPRING, STAGGER } from '@/lib/motion';

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

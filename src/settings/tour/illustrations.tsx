import { Badge, Box, Kbd, Skeleton, Text } from '@mantine/core';
import { EyeOff, Lock, Mic } from 'lucide-react';

import classes from './illustrations.module.css';

/**
 * The tour's literal mini-UI scenes: tiny working mockups of the real product,
 * not abstract art. Each loops while its slide is active and rests on a
 * complete end-frame otherwise (and always under reduced motion), so nothing
 * animates offscreen. All motion is transform/opacity in the CSS module.
 * Decorative throughout — the slide copy beside each scene carries the meaning.
 */

function Scene({ active, children }: { active: boolean; children: React.ReactNode }) {
  return (
    <div aria-hidden="true" className={`${classes.scene} ${active ? classes.animate : ''}`}>
      {children}
    </div>
  );
}

const BAR_HEIGHTS = [12, 22, 30, 18, 26];

/** Slide 1: hold the key, speak, watch the words land. */
export function DictateScene({ active }: { active: boolean }) {
  return (
    <Scene active={active}>
      <div className={classes.keyRow}>
        <span className={classes.keyPress}>
          <Kbd>Right Option</Kbd>
        </span>
        <Text size="xs" c="dimmed">
          held …
        </Text>
      </div>
      <div className={classes.bars}>
        {BAR_HEIGHTS.map(height => (
          <Box key={height} className={classes.bar} h={height} />
        ))}
      </div>
      <div className={`${classes.typed} ${classes.typedLoop}`}>
        “Meeting moved to three”
        <span className={classes.caret} />
      </div>
    </Scene>
  );
}

/** Slide 2: an instruction rewrites the sentence. */
export function EditScene({ active }: { active: boolean }) {
  return (
    <Scene active={active}>
      <div className={classes.chip}>
        <Badge variant="light" size="sm">
          “make it shorter”
        </Badge>
      </div>
      <div className={classes.before}>
        “The meeting that was planned for Friday”
        <span className={`${classes.strike} ${classes.strikeLoop}`} />
      </div>
      <div className={`${classes.after} ${classes.afterLoop}`}>“Meeting moved.” ✓</div>
    </Scene>
  );
}

/** Slide 3: a selected word blooms an answer card beside it. */
export function ExplainScene({ active }: { active: boolean }) {
  return (
    <Scene active={active}>
      <div className={classes.selRow}>
        <span className={`${classes.sel} ${classes.selLoop}`}>…idempotent…</span>
      </div>
      <div className={`${classes.miniCard} ${classes.cardLoop}`}>
        {active ? (
          <div className={classes.swap}>
            <div className={`${classes.skel} ${classes.skelLoop}`}>
              <Skeleton height={10} radius="sm" />
              <Skeleton height={10} radius="sm" width="82%" />
              <Skeleton height={10} radius="sm" width="64%" />
            </div>
            <div className={`${classes.prose} ${classes.proseLoop} ${classes.swapOverlay}`}>
              <p>Same result if repeated.</p>
              <p>PUT /users/1 twice ✓</p>
            </div>
          </div>
        ) : (
          <div className={classes.prose}>
            <p>Same result if repeated.</p>
            <p>PUT /users/1 twice ✓</p>
          </div>
        )}
      </div>
    </Scene>
  );
}

/** Slide 4: trust, mostly still — a shimmer and a breathing mic dot. */
export function TrustScene({ active }: { active: boolean }) {
  return (
    <Scene active={active}>
      <div className={classes.trustRow}>
        <span className={classes.lockWrap}>
          <Lock size={16} aria-hidden="true" />
          <span className={`${classes.shimmer} ${classes.shimmerLoop}`} />
        </span>
        <Text size="sm">keys → encrypted at rest</Text>
      </div>
      <div className={classes.trustRow}>
        <Mic size={16} aria-hidden="true" />
        <Text size="sm">mic live only while held</Text>
        <span className={`${classes.micDot} ${classes.dotLoop}`} />
      </div>
      <div className={classes.trustRow}>
        <EyeOff size={16} aria-hidden="true" />
        <Text size="sm">transcripts never stored</Text>
      </div>
    </Scene>
  );
}

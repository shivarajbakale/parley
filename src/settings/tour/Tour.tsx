import { Carousel } from '@mantine/carousel';
import { Box, Button, Group, Stack, Text, Title, VisuallyHidden } from '@mantine/core';
import { useEffect, useState } from 'react';

import { Pressable } from '../motion';
import { Scene, type SceneTone } from '../Scene';
import shell from '../settings.module.css';

import { DictateScene, EditScene, ExplainScene, TrustScene } from './illustrations';
import stage from './illustrations.module.css';

/**
 * Product tour, shown only when replayed from settings or the finale: four
 * peer slides of literal mini-UI scenes. Manual
 * advance only — no autoplay — with Skip always one click away and dots for
 * progress. Only the visible slide's scene animates; the rest sit on their
 * static end-frames.
 */

/** The slice of the Embla API the footer drives. Structural, so no new import. */
interface CarouselApi {
  selectedScrollSnap(): number;
  scrollNext(): void;
  scrollPrev(): void;
  on(event: 'select', cb: () => void): void;
  off(event: 'select', cb: () => void): void;
}

const SLIDES: {
  eyebrow: string;
  title: string;
  copy: string;
  tone: SceneTone;
  Scene: typeof DictateScene;
}[] = [
  {
    eyebrow: 'Meet Parley',
    tone: 'dictate',
    title: 'Hold to talk, release to paste',
    copy: 'Tap twice, hold the third press, speak, release — your words land where the cursor already is.',
    Scene: DictateScene,
  },
  {
    eyebrow: 'Voice edit',
    tone: 'edit',
    title: 'Say how to change it',
    copy: '“Make it shorter.” The text in the field rewrites itself around your words.',
    Scene: EditScene,
  },
  {
    eyebrow: 'Explain',
    tone: 'explain',
    title: 'Ask about anything',
    copy: 'Select text in any app and ask — a short answer appears beside it.',
    Scene: ExplainScene,
  },
  {
    eyebrow: 'Private by design',
    tone: 'neutral',
    title: 'Yours alone',
    copy: 'Keys stay encrypted on your Mac, the mic is live only while you hold, and transcripts are never stored.',
    Scene: TrustScene,
  },
];

export function Tour({ onDone, initialSlide = 0 }: { onDone(): void; initialSlide?: number }) {
  const [api, setApi] = useState<CarouselApi | null>(null);
  const [index, setIndex] = useState(() => Math.min(Math.max(initialSlide, 0), SLIDES.length - 1));
  const last = index === SLIDES.length - 1;

  // Sync from Embla on movement only. The mount value comes from
  // `initialSlide` above: Embla starts there too, and reading it back on
  // mount would clobber the state where Embla cannot measure (jsdom).
  useEffect(() => {
    if (!api) return;
    const onSelect = () => setIndex(api.selectedScrollSnap());
    api.on('select', onSelect);
    return () => {
      api.off('select', onSelect);
    };
  }, [api]);

  return (
    <Scene tone={SLIDES[index].tone}>
      <Stack h="100%" gap={0}>
        <Group justify="flex-end" px="md" pt="sm">
          <Button variant="subtle" size="xs" onClick={onDone}>
            Skip tour
          </Button>
        </Group>
        <VisuallyHidden>
          <h1>Welcome to Parley</h1>
        </VisuallyHidden>
        <Carousel
          aria-label="Product tour"
          flex={1}
          withIndicators
          withControls={false}
          slideSize="100%"
          emblaOptions={{ loop: false }}
          initialSlide={initialSlide}
          getEmblaApi={setApi}
        >
          {SLIDES.map(({ eyebrow, title, copy, Scene: Illustration }, slide) => (
            <Carousel.Slide key={title}>
              <Stack align="center" gap="md" px="xl" pb="xl" mih={380}>
                <Box className={stage.stage} w="100%">
                  <Illustration active={slide === index} />
                </Box>
                <Stack align="center" gap={4}>
                  <Text
                    size="xs"
                    fw={600}
                    tt="uppercase"
                    c="dimmed"
                    style={{ letterSpacing: '0.08em' }}
                  >
                    {eyebrow}
                  </Text>
                  <Title order={2} ta="center">
                    {title}
                  </Title>
                  <Text size="sm" c="dimmed" ta="center" maw={440}>
                    {copy}
                  </Text>
                </Stack>
              </Stack>
            </Carousel.Slide>
          ))}
        </Carousel>
        <Group justify="space-between" px="md" pb="md">
          <Box style={{ visibility: index > 0 ? 'visible' : 'hidden' }}>
            <Pressable>
              <Button variant="default" onClick={() => api?.scrollPrev()}>
                Back
              </Button>
            </Pressable>
          </Box>
          <Pressable>
            {last ? (
              <Button size="md" className={shell.primary} onClick={onDone}>
                Done
              </Button>
            ) : (
              <Button className={shell.primary} onClick={() => api?.scrollNext()}>
                Next
              </Button>
            )}
          </Pressable>
        </Group>
      </Stack>
    </Scene>
  );
}

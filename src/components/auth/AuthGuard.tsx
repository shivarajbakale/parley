import { useEffect } from 'react';
import { useRouter } from '@tanstack/react-router';
import { Center, Loader } from '@mantine/core';

import { useSession } from '@/lib/auth';

interface AuthGuardProps {
  children: React.ReactNode;
}

export function AuthGuard({ children }: AuthGuardProps) {
  const { data: session, isPending } = useSession();
  const router = useRouter();

  useEffect(() => {
    if (!isPending && !session) {
      router.navigate({ to: '/login' });
    }
  }, [session, isPending, router]);

  if (isPending) {
    // `Loader` rather than a hand-spun ring: it is one element, it respects
    // `respectReducedMotion` from the theme, and it reads the brand colour
    // instead of naming `border-primary` a second time.
    return (
      <Center h="100svh" style={{ overflow: 'hidden' }}>
        <Loader size="md" />
      </Center>
    );
  }

  if (!session) return null;

  return <>{children}</>;
}

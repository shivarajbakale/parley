import { useState } from 'react';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import { Link, useRouter } from '@tanstack/react-router';
import {
  Alert,
  Anchor,
  Button,
  Divider,
  Group,
  PasswordInput,
  SimpleGrid,
  Stack,
  Text,
  TextInput,
  Title,
} from '@mantine/core';

import { signIn } from '@/lib/auth';
import { PROVIDER_LABELS, PROVIDER_MARKS } from '@/lib/provider-marks';
import { AuthLayout } from './AuthLayout';

const loginSchema = z.object({
  email: z.string().email('Please enter a valid email'),
  password: z.string().min(8, 'Password must be at least 8 characters'),
});

type LoginForm = z.infer<typeof loginSchema>;

export function LoginPage() {
  const router = useRouter();
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  const {
    register,
    handleSubmit,
    formState: { errors },
  } = useForm<LoginForm>({ resolver: zodResolver(loginSchema) });

  const onSubmit = async (data: LoginForm) => {
    setError(null);
    setLoading(true);
    try {
      const result = await signIn.email({ email: data.email, password: data.password });
      if (result.error) setError(result.error.message || 'Invalid email or password');
      else router.navigate({ to: '/' });
    } catch {
      setError('Something went wrong. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <AuthLayout>
      <Stack gap={6} mb="xl">
        <Title order={1} size="h3">
          Welcome back
        </Title>
        <Text size="sm" c="dimmed">
          Sign in to your account to continue.
        </Text>
      </Stack>

      <SimpleGrid cols={2} spacing="xs">
        <SocialButton provider="google" />
        <SocialButton provider="github" />
      </SimpleGrid>

      {/* Mantine's Divider draws its own label centred on the rule, which is the
          three-element absolute-positioned recipe this page used to carry. */}
      <Divider my="lg" label="or" labelPosition="center" />

      <form onSubmit={handleSubmit(onSubmit)}>
        {error && (
          <Alert color="red" variant="light" mb="md">
            {error}
          </Alert>
        )}

        <Stack gap="md">
          {/* Mantine inputs own their label, description and error slot, so a
              field is one component rather than a Label/Input/error stack — and
              the error is wired to the control by `aria-describedby` without the
              page arranging it. */}
          <TextInput
            id="email"
            label="Email"
            type="email"
            autoComplete="email"
            placeholder="you@example.com"
            error={errors.email?.message}
            {...register('email')}
          />

          <PasswordInput
            id="password"
            label="Password"
            autoComplete="current-password"
            placeholder="••••••••"
            error={errors.password?.message}
            labelProps={{ style: { width: '100%' } }}
            {...register('password')}
          />
          <Group justify="flex-end" mt={-12}>
            <Anchor component="button" type="button" size="xs" c="dimmed">
              Forgot password?
            </Anchor>
          </Group>

          <Button type="submit" fullWidth loading={loading}>
            Sign in
          </Button>
        </Stack>
      </form>

      <Text size="sm" c="dimmed" ta="center" mt="lg">
        Don&apos;t have an account?{' '}
        <Anchor component={Link} to="/signup" fw={500} underline="hover">
          Sign up
        </Anchor>
      </Text>
      <Text size="xs" c="dimmed" ta="center" mt="xs">
        Demo mode — any valid email and an 8+ character password works.
      </Text>
    </AuthLayout>
  );
}

export function SocialButton({ provider }: { provider: 'google' | 'github' }) {
  return (
    <Button
      variant="default"
      type="button"
      disabled
      fullWidth
      leftSection={
        <svg width={16} height={16} viewBox="0 0 24 24" aria-hidden>
          {PROVIDER_MARKS[provider].map((path) => (
            <path key={path.d} d={path.d} fill={path.fill} />
          ))}
        </svg>
      }
    >
      {PROVIDER_LABELS[provider]}
    </Button>
  );
}

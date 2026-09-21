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
  PasswordInput,
  SimpleGrid,
  Stack,
  Text,
  TextInput,
  Title,
} from '@mantine/core';

import { signUp } from '@/lib/auth';
import { AuthLayout } from './AuthLayout';
import { SocialButton } from './LoginPage';

const signupSchema = z.object({
  name: z.string().min(2, 'Please enter your name'),
  email: z.string().email('Please enter a valid email'),
  password: z.string().min(8, 'Password must be at least 8 characters'),
});

type SignupForm = z.infer<typeof signupSchema>;

export function SignupPage() {
  const router = useRouter();
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  const {
    register,
    handleSubmit,
    formState: { errors },
  } = useForm<SignupForm>({ resolver: zodResolver(signupSchema) });

  const onSubmit = async (data: SignupForm) => {
    setError(null);
    setLoading(true);
    try {
      const result = await signUp.email({
        name: data.name,
        email: data.email,
        password: data.password,
      });
      if (result.error) setError(result.error.message || 'Registration failed');
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
          Create your account
        </Title>
        <Text size="sm" c="dimmed">
          Start building in under a minute.
        </Text>
      </Stack>

      <SimpleGrid cols={2} spacing="xs">
        <SocialButton provider="google" />
        <SocialButton provider="github" />
      </SimpleGrid>

      <Divider my="lg" label="or" labelPosition="center" />

      <form onSubmit={handleSubmit(onSubmit)}>
        {error && (
          <Alert color="red" variant="light" mb="md">
            {error}
          </Alert>
        )}

        <Stack gap="md">
          <TextInput
            id="name"
            label="Name"
            autoComplete="name"
            placeholder="Ada Lovelace"
            error={errors.name?.message}
            {...register('name')}
          />

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
            autoComplete="new-password"
            placeholder="••••••••"
            error={errors.password?.message}
            {...register('password')}
          />

          <Button type="submit" fullWidth loading={loading}>
            Create account
          </Button>
        </Stack>
      </form>

      <Text size="sm" c="dimmed" ta="center" mt="lg">
        Already have an account?{' '}
        <Anchor component={Link} to="/login" fw={500} underline="hover">
          Sign in
        </Anchor>
      </Text>
    </AuthLayout>
  );
}

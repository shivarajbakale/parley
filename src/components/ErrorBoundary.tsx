import React from 'react';
import { Button, Code, Group, ScrollArea, Stack, Text, Title } from '@mantine/core';

interface ErrorBoundaryState {
  hasError: boolean;
  error: Error | null;
}

interface ErrorBoundaryProps {
  children: React.ReactNode;
  fallback?: React.ReactNode;
}

export class ErrorBoundary extends React.Component<ErrorBoundaryProps, ErrorBoundaryState> {
  constructor(props: ErrorBoundaryProps) {
    super(props);
    this.state = { hasError: false, error: null };
  }

  static getDerivedStateFromError(error: Error): ErrorBoundaryState {
    return { hasError: true, error };
  }

  componentDidCatch(error: Error, errorInfo: React.ErrorInfo) {
    console.error('ErrorBoundary caught:', error, errorInfo);
  }

  handleReset = () => {
    this.setState({ hasError: false, error: null });
  };

  render() {
    if (this.state.hasError) {
      if (this.props.fallback) {
        return this.props.fallback;
      }

      return (
        <Stack align="center" justify="center" gap="md" p="xl" mih={400}>
          <Title order={2} size="h4">
            Something went wrong
          </Title>
          <Text c="dimmed" ta="center" maw={480}>
            An unexpected error occurred. Please try again.
          </Text>
          {import.meta.env.DEV && this.state.error && (
            <ScrollArea.Autosize mah={192} maw={512} w="100%">
              {/* `Code block` rather than a tinted <pre>: the surface, the mono
                  stack and the radius are the theme's, so a dev-only panel does
                  not become the one place with its own idea of them. */}
              <Code block>{this.state.error.message}</Code>
            </ScrollArea.Autosize>
          )}
          <Group gap="sm">
            <Button onClick={this.handleReset}>Try again</Button>
            <Button variant="default" onClick={() => (window.location.href = '/')}>
              Go home
            </Button>
          </Group>
        </Stack>
      );
    }

    return this.props.children;
  }
}

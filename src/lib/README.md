# Lib Directory

This directory contains shared library code and configuration used throughout the application.

## Files

### `queryClient.ts`

Configuration for TanStack Query (React Query) client with optimized defaults for Electron desktop applications.

**Configuration:**

- `refetchOnWindowFocus: false` - Disabled for desktop apps (no tab switching)
- `retry: 2` - Retry failed requests up to 2 times
- `staleTime: 5 minutes` - Data is considered fresh for 5 minutes
- `gcTime: 10 minutes` - Unused data is kept in cache for 10 minutes

**Usage:**

```typescript
import { queryClient } from '@/lib/queryClient';

// The client is already provided in App.tsx via QueryClientProvider
// You can access it in components using useQueryClient():

import { useQueryClient } from '@tanstack/react-query';

function MyComponent() {
  const queryClient = useQueryClient();

  // Manually invalidate queries
  queryClient.invalidateQueries({ queryKey: ['todos'] });

  // Clear all cache
  queryClient.clear();
}
```

## Adding New Library Files

When adding new shared library code:

1. Create the file in this directory (`src/lib/`)
2. Export the necessary functions/constants
3. Import using the `@/lib/` path alias
4. Document the purpose and usage in this README

### Examples of what belongs here:

- API client configuration (axios, fetch)
- Query client configuration (TanStack Query)
- Utility functions used across multiple features
- Shared constants and configuration
- Third-party library setup and configuration

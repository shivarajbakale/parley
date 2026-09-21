# Mock Service Worker (MSW) Setup Guide

## Quick Start

MSW (Mock Service Worker) is now configured in this project for API mocking during development and testing.

### Enable MSW in Development

1. **Create a `.env` file** (if not exists):

   ```bash
   cp .env.example .env
   ```

2. **Enable mocking** in `.env`:

   ```env
   VITE_ENABLE_MOCKING=true
   ```

3. **Start the development server**:

   ```bash
   npm run dev
   ```

4. **Check the console** - You should see:
   ```
   [MSW] Mocking enabled.
   ```

All API requests to `/api/*` will now be intercepted and mocked!

## What's Included

### Mock Endpoints

The following API endpoints are already mocked:

#### Todos

- `GET /api/todos` - Get all todos (with filtering and pagination)
- `GET /api/todos/:id` - Get a single todo
- `POST /api/todos` - Create a new todo
- `PUT /api/todos/:id` - Update a todo (full update)
- `PATCH /api/todos/:id` - Update a todo (partial update)
- `PATCH /api/todos/:id/toggle` - Toggle todo completion
- `DELETE /api/todos/:id` - Delete a todo
- `POST /api/todos/bulk-delete` - Bulk delete todos
- `POST /api/todos/bulk-update` - Bulk update todos

#### Authentication

- `POST /api/auth/login` - User login
- `POST /api/auth/register` - User registration
- `POST /api/auth/refresh` - Refresh access token
- `POST /api/auth/logout` - User logout
- `GET /api/auth/me` - Get current user

### Test Credentials

For authentication endpoints, use:

- **Email**: `demo@example.com`
- **Password**: `password`

## File Structure

```
src/
├── mocks/
│   ├── handlers.ts       # API endpoint handlers
│   ├── browser.ts        # Browser setup (development)
│   ├── node.ts           # Node setup (testing)
│   └── README.md         # Detailed documentation
├── test/
│   ├── setup.ts          # Test setup with MSW
│   └── example.test.ts   # Example tests
└── main.tsx              # MSW initialization
```

## Development Workflow

### Using Mock Data

When MSW is enabled, all API requests are intercepted:

```typescript
// This will use mock data from handlers.ts
const response = await fetch('/api/todos');
const data = await response.json();
console.log(data); // Mock todos
```

### Switching to Real API

To use your real backend API:

1. Set `VITE_ENABLE_MOCKING=false` in `.env`
2. Configure `VITE_API_BASE_URL` in `.env`:
   ```env
   VITE_API_BASE_URL=http://localhost:3000/api
   ```
3. Restart the dev server

### Hybrid Approach

You can also selectively mock only some endpoints:

```typescript
// In handlers.ts, only add handlers for endpoints you want to mock
// Other endpoints will pass through to the real API
```

## Testing

MSW is automatically enabled for all tests via `src/test/setup.ts`.

### Running Tests

```bash
npm test
```

### Example Test

```typescript
import { describe, it, expect } from 'vitest';

describe('TodoList', () => {
  it('should fetch todos', async () => {
    const response = await fetch('/api/todos');
    const data = await response.json();

    expect(data.success).toBe(true);
    expect(data.data).toHaveLength(5);
  });
});
```

### Overriding Handlers in Tests

```typescript
import { server } from '@/mocks/node';
import { http, HttpResponse } from 'msw';

it('should handle empty list', async () => {
  // Override for this test only
  server.use(
    http.get('/api/todos', () => {
      return HttpResponse.json({
        success: true,
        data: [],
      });
    })
  );

  const response = await fetch('/api/todos');
  const data = await response.json();

  expect(data.data).toHaveLength(0);
});
```

## Customization

### Adding New Endpoints

Edit `src/mocks/handlers.ts`:

```typescript
export const handlers = [
  // ... existing handlers

  // Add new endpoint
  http.get('/api/products', () => {
    return HttpResponse.json({
      success: true,
      data: [
        { id: 1, name: 'Product 1', price: 99.99 },
        { id: 2, name: 'Product 2', price: 149.99 },
      ],
    });
  }),
];
```

### Modifying Mock Data

Mock data is stored in memory in `handlers.ts`:

```typescript
let mockTodos: Todo[] = [
  { id: 1, title: 'Todo 1', description: 'Desc 1', completed: false },
  // Add more todos here
];
```

### Simulating Delays

Add network delays to simulate real-world conditions:

```typescript
http.get('/api/todos', async () => {
  await new Promise(resolve => setTimeout(resolve, 1000)); // 1 second delay

  return HttpResponse.json({
    success: true,
    data: mockTodos,
  });
});
```

### Simulating Errors

Test error handling:

```typescript
http.get('/api/todos', () => {
  return HttpResponse.json(
    {
      success: false,
      message: 'Database connection failed',
    },
    { status: 500 }
  );
});
```

## Features

### Pagination

```bash
GET /api/todos?page=1&limit=10
```

Returns:

```json
{
  "data": [...],
  "pagination": {
    "page": 1,
    "limit": 10,
    "total": 50,
    "totalPages": 5,
    "hasMore": true
  }
}
```

### Filtering

```bash
GET /api/todos?status=active&search=important
```

Filters by:

- `status`: "active", "completed", "all"
- `search`: Search in title and description

### Validation

Invalid requests return proper error responses:

```json
{
  "success": false,
  "message": "Validation failed",
  "errors": {
    "title": ["Title is required"],
    "description": ["Description is required"]
  }
}
```

## Troubleshooting

### MSW not intercepting requests

**Problem**: Requests are going to the real API instead of being mocked.

**Solutions**:

1. Check `VITE_ENABLE_MOCKING=true` in `.env`
2. Restart the dev server
3. Clear browser cache and reload
4. Check DevTools > Application > Service Workers

### Service Worker registration failed

**Problem**: MSW fails to start.

**Solutions**:

1. Ensure you're using `localhost` or `https`
2. Service Workers don't work with `file://` protocol
3. Check browser console for errors

### Tests failing with network errors

**Problem**: Tests can't reach mock API.

**Solutions**:

1. Verify `src/test/setup.ts` is in Vitest config
2. Check that handlers match your request URLs
3. Look for errors in test output

### Mock data not persisting

**Problem**: Mock data resets on page reload.

**Solution**: Mock data is stored in memory. To persist:

- Use `localStorage` in handlers
- Use IndexedDB for larger datasets
- Connect to a real backend for persistence

## Best Practices

1. **Match real API responses**: Use the same structure as your backend
2. **Handle all status codes**: Test 200, 201, 400, 401, 404, 500
3. **Add validation**: Validate request bodies like your real API
4. **Use realistic data**: Make mock data look like production data
5. **Document endpoints**: Add comments explaining each handler
6. **Test edge cases**: Empty lists, large datasets, errors
7. **Keep it simple**: Don't add unnecessary complexity

## Resources

- [MSW Documentation](https://mswjs.io/docs/)
- [MSW Examples](https://mswjs.io/docs/basics/examples)
- [Detailed README](../src/mocks/README.md)

## Next Steps

1. ✅ MSW is installed and configured
2. ✅ Example handlers are set up
3. ✅ Test examples are provided
4. 🔄 Enable mocking in `.env`
5. 🔄 Customize handlers for your API
6. 🔄 Add more endpoints as needed
7. 🔄 Write tests using MSW

# MSW Troubleshooting Guide

## Common Issues and Solutions

### 1. Service Worker Registration Failed

**Error:**

```
Failed to register a ServiceWorker for scope ('http://localhost:5173/') with script ('http://localhost:5173/mockServiceWorker.js'): The script has an unsupported MIME type ('text/html').
```

**Cause:** The `mockServiceWorker.js` file is missing from the `public/` directory.

**Solution:**

```bash
# Run this command in your project root
npx msw init public/ --save
```

This creates the `public/mockServiceWorker.js` file that MSW needs.

---

### 2. MSW Not Intercepting Requests

**Symptoms:**

- Requests go to the real API instead of being mocked
- No `[MSW]` logs in the console
- Service Worker not showing in DevTools

**Solutions:**

#### Check if MSW is enabled:

```bash
# Ensure .env has this line
VITE_ENABLE_MOCKING=true
```

#### Restart the dev server:

```bash
npm run dev
```

#### Check Service Worker registration:

1. Open DevTools → Application → Service Workers
2. You should see a Service Worker registered for `localhost:5173`
3. If not, try clearing Service Workers and reloading

#### Check console for MSW logs:

You should see: `[MSW] Mocking enabled.`

---

### 3. Service Worker Not Updating

**Symptoms:**

- Changes to handlers don't reflect
- Old mock data still showing

**Solutions:**

#### Force reload:

```
Cmd/Ctrl + Shift + R (hard refresh)
```

#### Unregister Service Worker:

1. DevTools → Application → Service Workers
2. Click "Unregister"
3. Reload the page

#### Clear browser cache:

1. DevTools → Application → Clear storage
2. Check "Service Workers"
3. Click "Clear site data"
4. Reload

---

### 4. CORS Errors with MSW

**Symptoms:**

- CORS errors even though MSW is enabled
- Requests blocked by CORS policy

**Solution:**
MSW should handle CORS automatically. If you see CORS errors:

1. Check that your request URL matches the handler pattern exactly
2. Ensure the Service Worker is registered
3. Try restarting the dev server

---

### 5. Handlers Not Matching Requests

**Symptoms:**

- Requests not being intercepted
- Getting 404 or actual API responses

**Solutions:**

#### Check the URL pattern:

```typescript
// Wrong - missing /api prefix
http.get('/todos', ...)

// Correct - matches your API calls
http.get('/api/todos', ...)
```

#### Check the request method:

```typescript
// Handler is GET but you're making POST
http.get('/api/todos', ...)
fetch('/api/todos', { method: 'POST' }) // Won't match

// Should be:
http.post('/api/todos', ...)
```

#### Check for typos:

```typescript
// Handler
http.get('/api/todos/:id', ...)

// Request (wrong)
fetch('/api/todo/1') // Missing 's' - won't match

// Request (correct)
fetch('/api/todos/1')
```

---

### 6. TypeScript Errors

**Error:**

```
Cannot find module './handlers' or its corresponding type declarations
```

**Solution:**
Ensure all handler files are properly exported:

```typescript
// In handlers/index.ts
export { handlers } from './index';
```

---

### 7. Tests Failing with Network Errors

**Symptoms:**

- Tests can't find mock endpoints
- Network errors in test output

**Solutions:**

#### Check test setup:

Ensure `src/test/setup.ts` is configured in `vite.config.ts`:

```typescript
test: {
  setupFiles: './src/test/setup.ts',
}
```

#### Verify MSW server is started:

In `src/test/setup.ts`:

```typescript
import { server } from '../mocks/node';

beforeAll(() => server.listen());
afterEach(() => server.resetHandlers());
afterAll(() => server.close());
```

#### Check handler URLs match:

```typescript
// Your component
fetch('/api/todos')

// Your test handler must match
http.get('/api/todos', ...)
```

---

### 8. Port Conflicts

**Issue:** MSW doesn't have its own port - it runs on your app's port.

**How it works:**

- Development: Uses your Vite dev server port (default: 5173)
- Testing: Runs in-process with your tests

**No separate port configuration needed!**

---

### 9. Mock Data Not Persisting

**Symptoms:**

- Mock data resets on page reload
- Changes to mock data don't persist

**Explanation:**
This is expected behavior. Mock data is stored in memory.

**Solutions:**

#### Option 1: Use localStorage (in handlers)

```typescript
let mockTodos: Todo[] = JSON.parse(
  localStorage.getItem('mockTodos') || JSON.stringify(DEFAULT_TODOS)
);

// After mutations
localStorage.setItem('mockTodos', JSON.stringify(mockTodos));
```

#### Option 2: Use IndexedDB

For larger datasets, use IndexedDB in your handlers.

#### Option 3: Connect to real backend

Set `VITE_ENABLE_MOCKING=false` and configure `VITE_API_BASE_URL`.

---

### 10. MSW Not Working in Electron

**Issue:** Service Workers might not work the same way in Electron.

**Solutions:**

#### Option 1: Use MSW in renderer only

MSW should work in the renderer process (web pages).

#### Option 2: Mock in main process

For main process API calls, consider:

- Using MSW with the Node.js adapter
- Creating a local Express server for mocking
- Using Electron IPC with mock data

#### Option 3: Use Electron IPC adapter

See the API Integration Expert documentation for Electron IPC patterns.

---

## Quick Diagnostic Checklist

Run through this checklist to diagnose issues:

- [ ] `mockServiceWorker.js` exists in `public/` directory
- [ ] `.env` has `VITE_ENABLE_MOCKING=true`
- [ ] Dev server has been restarted after `.env` changes
- [ ] Console shows `[MSW] Mocking enabled.`
- [ ] DevTools → Application → Service Workers shows registered worker
- [ ] Handler URL patterns match your fetch/axios calls exactly
- [ ] Request methods (GET/POST/etc.) match handler methods
- [ ] For tests: `src/test/setup.ts` is configured in `vite.config.ts`

---

## Getting Help

If you're still having issues:

1. **Check the MSW documentation**: https://mswjs.io/docs/
2. **Check browser console** for error messages
3. **Check DevTools → Network** to see if requests are being intercepted
4. **Check DevTools → Application → Service Workers** for registration status
5. **Try the example test** in `src/test/example.test.ts` to verify setup

---

## Useful Commands

```bash
# Initialize MSW (creates service worker file)
npx msw init public/ --save

# Clear Service Worker cache
# DevTools → Application → Service Workers → Unregister

# Run tests with MSW
npm test

# Start dev server with mocking
VITE_ENABLE_MOCKING=true npm run dev
```

---

## File Structure Reference

```
project/
├── public/
│   └── mockServiceWorker.js       # ← Must exist!
├── src/
│   ├── mocks/
│   │   ├── handlers.ts             # Main export
│   │   ├── handlers/
│   │   │   ├── index.ts           # Combines all handlers
│   │   │   ├── todoHandlers.ts    # Feature handlers
│   │   │   └── authHandlers.ts    # Feature handlers
│   │   ├── types.ts               # Response types
│   │   ├── browser.ts             # Browser setup
│   │   └── node.ts                # Node setup (tests)
│   ├── test/
│   │   └── setup.ts               # Test configuration
│   └── main.tsx                   # MSW initialization
├── .env                           # VITE_ENABLE_MOCKING=true
└── vite.config.ts                 # Test setup file config
```

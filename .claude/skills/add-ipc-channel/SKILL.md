---
name: add-ipc-channel
description: Add a secure Electron IPC channel end-to-end (main-process handler → preload bridge → typed renderer call). Use when the renderer needs a native/OS capability (file dialogs, filesystem, notifications, window controls, secure storage) that only the main process can do.
---

# add-ipc-channel — renderer ↔ main, securely

`contextIsolation` is on and `nodeIntegration` is off (keep them that way). The
renderer reaches the OS only through channels exposed by the preload bridge.

## The three edits

1. **Main process** (`electron/main.ts`) — register a handler for request/response
   with `ipcMain.handle`:
   ```ts
   import { ipcMain, dialog } from 'electron';
   ipcMain.handle('dialog:openFile', async () => {
     const { canceled, filePaths } = await dialog.showOpenDialog({ properties: ['openFile'] });
     return canceled ? null : filePaths[0];
   });
   ```
   **Validate every argument** — the renderer is untrusted input.
2. **Preload bridge** (`electron/preload.ts`) — the generic `ipcRenderer` bridge
   already forwards `invoke`/`send`/`on`. For a first-class API, expose a named
   method instead of a raw channel:
   ```ts
   contextBridge.exposeInMainWorld('api', {
     openFile: () => ipcRenderer.invoke('dialog:openFile'),
   });
   ```
   Add its type to `electron/electron-env.d.ts` (`interface Window { api: … }`).
3. **Renderer** — call it from a component/hook:
   ```ts
   const path = await window.api.openFile();
   ```
   For data flows, wrap the call in a TanStack Query hook (see `src/hooks/`) so
   loading/error state is handled consistently.

## Rules

- Use `invoke`/`handle` for request→response; use `send` + `webContents.send`
  only for fire-and-forget or main→renderer pushes (see the existing
  `main-process-message` example in `electron/main.ts`).
- Never expose `ipcRenderer` methods that take an arbitrary channel to product
  code — prefer named, typed methods on a small `window.api`.
- Never enable `nodeIntegration` or disable `contextIsolation`.

## Verify

`npm run type-check`, then `npm run dev` (launches Electron) and exercise the new
capability; confirm no errors in the main-process or renderer console.

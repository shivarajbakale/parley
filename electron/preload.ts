import { ipcRenderer, contextBridge } from 'electron';

import type {
  OrbPhasePayload,
  ParleyApi,
  PermissionKind,
  RecordedAudio,
  Settings,
} from './types';

// --------- Expose some API to the Renderer process ---------
contextBridge.exposeInMainWorld('ipcRenderer', {
  on(...args: Parameters<typeof ipcRenderer.on>) {
    const [channel, listener] = args;
    return ipcRenderer.on(channel, (event, ...args) => listener(event, ...args));
  },
  off(...args: Parameters<typeof ipcRenderer.off>) {
    const [channel, ...omit] = args;
    return ipcRenderer.off(channel, ...omit);
  },
  send(...args: Parameters<typeof ipcRenderer.send>) {
    const [channel, ...omit] = args;
    return ipcRenderer.send(channel, ...omit);
  },
  invoke(...args: Parameters<typeof ipcRenderer.invoke>) {
    const [channel, ...omit] = args;
    return ipcRenderer.invoke(channel, ...omit);
  },

  // You can expose other APTs you need here.
  // ...
});

const parley: ParleyApi = {
  onOrbPhase(listener) {
    const handler = (_event: Electron.IpcRendererEvent, payload: OrbPhasePayload) =>
      listener(payload);
    ipcRenderer.on('orb:phase', handler);
    return () => {
      ipcRenderer.off('orb:phase', handler);
    };
  },
  sendAudio: (audio: RecordedAudio) => ipcRenderer.send('orb:audio', audio),
  getSettings: () => ipcRenderer.invoke('settings:get'),
  updateSettings: (patch: Partial<Settings>) => ipcRenderer.invoke('settings:update', patch),
  setApiKey: (key: string) => ipcRenderer.invoke('settings:setApiKey', key),
  getPermissions: () => ipcRenderer.invoke('permissions:get'),
  requestPermission: (kind: PermissionKind) => ipcRenderer.invoke('permissions:request', kind),
};

contextBridge.exposeInMainWorld('parley', parley);

import { ipcRenderer, contextBridge } from 'electron';

/**
 * The only renderer/main seam. `window.parley` is a fixed set of named methods;
 * there is deliberately no generic bridge that forwards an arbitrary channel.
 */

import type {
  OrbPhasePayload,
  ParleyApi,
  PermissionKind,
  RecordedAudio,
  Settings,
} from './types';

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

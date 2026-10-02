import { ipcRenderer, contextBridge } from 'electron';

/**
 * The only renderer/main seam. `window.parley` is a fixed set of named methods;
 * there is deliberately no generic bridge that forwards an arbitrary channel.
 */

import type {
  ExplainState,
  OrbPhasePayload,
  ParleyApi,
  PermissionKind,
  RecordedAudio,
  SessionBlockedReason,
  Settings,
  TranscriptionProvider,
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
  setDeepgramKey: (key: string) => ipcRenderer.invoke('settings:setDeepgramKey', key),
  setTranscriptionProvider: (provider: TranscriptionProvider) =>
    ipcRenderer.invoke('settings:setTranscriptionProvider', provider),
  setRewriteKey: (key: string) => ipcRenderer.invoke('settings:setRewriteKey', key),
  setAgentUrl: (url: string) => ipcRenderer.invoke('agent:setUrl', url),
  testAgent: () => ipcRenderer.invoke('agent:test'),
  restartAgent: () => ipcRenderer.invoke('agent:restart'),
  decideApproval: (callId: string, approved: boolean) =>
    ipcRenderer.invoke('agent:decideApproval', callId, approved),
  agentStatus: () => ipcRenderer.invoke('agent:status'),
  signInSync: (email: string) => ipcRenderer.invoke('sync:signIn', email),
  signOutSync: () => ipcRenderer.invoke('sync:signOut'),
  syncNow: () => ipcRenderer.invoke('sync:now'),
  getPermissions: () => ipcRenderer.invoke('permissions:get'),
  requestPermission: (kind: PermissionKind) => ipcRenderer.invoke('permissions:request', kind),
  onExplain(listener) {
    const handler = (_event: Electron.IpcRendererEvent, state: ExplainState) => listener(state);
    ipcRenderer.on('explain:state', handler);
    return () => {
      ipcRenderer.off('explain:state', handler);
    };
  },
  reportExplainHeight: (height: number) => ipcRenderer.send('explain:height', height),
  copyExplain: (text: string) => ipcRenderer.send('explain:copy', text),
  dismissExplain: () => ipcRenderer.send('explain:dismiss'),
  openExternal: (url: string) => ipcRenderer.send('explain:openExternal', url),
  onSessionBlocked(listener) {
    const handler = (_event: Electron.IpcRendererEvent, reason: SessionBlockedReason) =>
      listener(reason);
    ipcRenderer.on('session:blocked', handler);
    return () => {
      ipcRenderer.off('session:blocked', handler);
    };
  },
  takeBlockedReason: () => ipcRenderer.invoke('session:take-blocked'),
};

contextBridge.exposeInMainWorld('parley', parley);

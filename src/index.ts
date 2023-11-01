import { NativeModulesProxy, EventEmitter, Subscription } from 'expo-modules-core';

// Import the native module. On web, it will be resolved to ExpoAudioFFT.web.ts
// and on native platforms to ExpoAudioFFT.ts
import ExpoAudioFFTModule from './ExpoAudioFFTModule';
import ExpoAudioFFTView from './ExpoAudioFFTView';
import { ChangeEventPayload, ExpoAudioFFTViewProps } from './ExpoAudioFFT.types';

// Get the native constant value.
export const PI = ExpoAudioFFTModule.PI;

export function hello(): string {
  return ExpoAudioFFTModule.hello();
}

export async function setValueAsync(value: string) {
  return await ExpoAudioFFTModule.setValueAsync(value);
}

const emitter = new EventEmitter(ExpoAudioFFTModule ?? NativeModulesProxy.ExpoAudioFFT);

export function addChangeListener(listener: (event: ChangeEventPayload) => void): Subscription {
  return emitter.addListener<ChangeEventPayload>('onChange', listener);
}

export { ExpoAudioFFTView, ExpoAudioFFTViewProps, ChangeEventPayload };

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

export function init(): string {
  return ExpoAudioFFTModule.init();
}

export function load(localUri: string): string {
  return ExpoAudioFFTModule.load(localUri);
}

export function play(): string {
  return ExpoAudioFFTModule.play();
}

export function pause(): string {
  return ExpoAudioFFTModule.pause();
}

export function stop(): string {
  return ExpoAudioFFTModule.pause();
}

export function seek(toSeconds: number): string {
  return ExpoAudioFFTModule.seek(toSeconds);
}

export type AudioMetadata = {
  duration: number, 
  numChannels: number,
  sampleRate: number,
  totalSamples: number
}

export function getMetadata(localUri: string): AudioMetadata {
  return ExpoAudioFFTModule.getMetadata(localUri);
}

export function setBandingOptions(numBands: number, bandingMethod: "logarithmic" | "linear" | "avg" | "min" | "max" = "logarithmic") {
  return ExpoAudioFFTModule.setBandingOptions(numBands, bandingMethod);
}

export async function getWaveformData(localUri: string, sampleCount: number): Promise<number[]> {
  return await ExpoAudioFFTModule.getWaveformData(localUri, sampleCount);
}

const emitter = new EventEmitter(ExpoAudioFFTModule ?? NativeModulesProxy.ExpoAudioFFT);

export type AudioBufferEvent = {
  rawMagnitudes: number[],
  bandMagnitudes: number[],
  bandFrequencies: number[],
  loudness: number,
  currentTime: number
}

export function addAudioBufferListener(listener: (event: AudioBufferEvent) => void): Subscription {
  return emitter.addListener('onAudioBuffer', listener);
}

export function addProgressListener(listener: (event: { currentTime: number }) => void): Subscription {
  return emitter.addListener('onProgress', listener);
}

export { ExpoAudioFFTView, ExpoAudioFFTViewProps, ChangeEventPayload };

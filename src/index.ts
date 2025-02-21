import {
  NativeModulesProxy,
  EventEmitter,
  Subscription,
} from "expo-modules-core";

// Import the native module. On web, it will be resolved to ExpoAudioFFT.web.ts
// and on native platforms to ExpoAudioFFT.ts
import ExpoAudioFFTModule from "./ExpoAudioFFTModule";
import ExpoMetalShaderView from "./ExpoMetalShaderView";
import {
  ChangeEventPayload,
  ExpoAudioFFTViewProps,
} from "./ExpoAudioFFT.types";

// Get the native constant value.
export const PI = ExpoAudioFFTModule.PI;

export function hello(): string {
  return ExpoAudioFFTModule.hello();
}

export async function init(enableFFT = true): Promise<string> {
  return ExpoAudioFFTModule.init(enableFFT);
}

export async function load(localUri: string): Promise<string> {
  return ExpoAudioFFTModule.load(localUri);
}

export async function play(): Promise<string> {
  return ExpoAudioFFTModule.play();
}

export async function pause(): Promise<string> {
  return ExpoAudioFFTModule.pause();
}

export async function stop(): Promise<string> {
  return ExpoAudioFFTModule.pause();
}

export async function seek(toSeconds: number): Promise<string> {
  return ExpoAudioFFTModule.seek(toSeconds);
}

export function currentTime(): number {
  return ExpoAudioFFTModule.currentTime();
}

export type AudioMetadata = {
  duration: number;
  numChannels: number;
  sampleRate: number;
  totalSamples: number;
};

export function getMetadata(localUri: string): Promise<AudioMetadata> {
  return ExpoAudioFFTModule.getMetadata(localUri);
}

export function setBandingOptions(
  numBands: number,
  bandingMethod:
    | "logarithmic"
    | "linear"
    | "avg"
    | "min"
    | "max" = "logarithmic"
): Promise<void> {
  return ExpoAudioFFTModule.setBandingOptions(numBands, bandingMethod);
}

export async function getWaveformData(
  localUri: string,
  sampleCount: number
): Promise<number[]> {
  return await ExpoAudioFFTModule.getWaveformData(localUri, sampleCount);
}

const emitter = new EventEmitter(
  ExpoAudioFFTModule ?? NativeModulesProxy.ExpoAudioFFT
);

export type AudioBufferEvent = {
  rawMagnitudes: number[];
  bandMagnitudes: number[];
  bandFrequencies: number[];
  loudness: number;
  currentTime: number;
};

export function addAudioBufferListener(
  listener: (event: AudioBufferEvent) => void
): Subscription {
  return emitter.addListener("onAudioBuffer", listener);
}

export function addProgressListener(
  listener: (event: { currentTime: number }) => void
): Subscription {
  return emitter.addListener("onProgress", listener);
}

export { ExpoMetalShaderView, ExpoAudioFFTViewProps, ChangeEventPayload };

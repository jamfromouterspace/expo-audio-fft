import { requireNativeViewManager } from 'expo-modules-core';
import * as React from 'react';

import { ExpoAudioFFTViewProps } from './ExpoAudioFFT.types';

const NativeView: React.ComponentType<ExpoAudioFFTViewProps> =
  requireNativeViewManager('ExpoAudioFFT');

export default function ExpoAudioFFTView(props: ExpoAudioFFTViewProps) {
  return <NativeView {...props} />;
}

import * as React from 'react';

import { ExpoAudioFFTViewProps } from './ExpoAudioFFT.types';

export default function ExpoAudioFFTView(props: ExpoAudioFFTViewProps) {
  return (
    <div>
      <span>{props.name}</span>
    </div>
  );
}

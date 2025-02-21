import { requireNativeViewManager } from 'expo-modules-core';
import * as React from 'react';

import { ExpoMetalShaderViewProps, ExpoMetalShaderViewRef } from './ExpoMetalShaderView.types';

const NativeView: React.ComponentType<ExpoMetalShaderViewProps> =
  requireNativeViewManager('ExpoMetalShaderView');

const ExpoMetalShaderView = React.forwardRef<ExpoMetalShaderViewRef, ExpoMetalShaderViewProps>(
  (props, ref) => {
    return <NativeView {...props} ref={ref} />;
  }
);

export default ExpoMetalShaderView
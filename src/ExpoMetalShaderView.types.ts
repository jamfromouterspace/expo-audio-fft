import { MutableRefObject, RefAttributes } from 'react';
import type { StyleProp, View, ViewStyle } from 'react-native';

export type ErrorEventPayload = {
  message: string;
};

export type ExpoMetalShaderViewModuleEvents = {
  onError: (params: ErrorEventPayload) => void;
};
 
export type Uniforms =  {
  iResolution: [number, number]; // equivalent to SIMD2<Float>
  varFloat1: number;
  varFloat2: number;
  varFloat3: number;
  varCumulativeFloat1: number;
  varCumulativeFloat2: number;
  varCumulativeFloat3: number;

  color1: number[];
  color2: number[];
  color3: number[];

  intensity1: number;
  intensity2: number;
  intensity3: number;

  // cumulativeBass: number;
  // bass: number;

  moveToMusic: number;
  /** 64 element array */
  // spectrum: number[];
}

export interface ExpoMetalShaderViewRef {
  updateUniforms: (newUniforms: Partial<Uniforms>) => void;
}

export type ExpoMetalShaderViewProps = {
  shader: string;
  isPaused?: boolean;
  onError?: (event: { nativeEvent: ErrorEventPayload }) => void;
  style?: StyleProp<ViewStyle>;
} & RefAttributes<ExpoMetalShaderViewRef>;

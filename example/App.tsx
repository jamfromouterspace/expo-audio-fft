import { StyleSheet, Text, View } from 'react-native';

import * as ExpoAudioFFT from 'expo-audio-fft';

export default function App() {
  return (
    <View style={styles.container}>
      <Text>{ExpoAudioFFT.hello()}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#fff',
    alignItems: 'center',
    justifyContent: 'center',
  },
});

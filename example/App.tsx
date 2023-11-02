import { Alert, StyleSheet, Text, TouchableOpacity, View } from 'react-native';
import * as ExpoAudioFFT from 'expo-audio-fft';
import * as DocumentPicker from "expo-document-picker";
import * as FileSystem from "expo-file-system";

export default function App() {
  const onPickDocument = async () => {
    const result = await DocumentPicker.getDocumentAsync({
      copyToCacheDirectory: true,
      multiple: false,
      type: "audio/*",
    })
    if (result.canceled) return
    for (const asset of result.assets) {
      try {
        const cacheUri = asset.uri
        // move to Documents folder and collect metadata
        const id = crypto.randomUUID()
        const mimeType = asset.mimeType
        const ext = mimeType?.split("/")[1] ?? "mp3"
        const localUri = `${FileSystem.documentDirectory}${id}.${ext}`
        await FileSystem.copyAsync({
          from: cacheUri,
          to: localUri,
        })
        const size = asset.size
        const name = asset.name
        const modifiedAt = asset.lastModified
        const waveformData = await ExpoAudioFFT.getWaveformData(localUri, 10)
        console.log("🎉 waveform data", waveformData)
      } catch (err) {
        console.warn("Error adding song", err)
        Alert.alert(
          "Something went wrong",
        )
      }
    }
  }
  return (
    <View style={styles.container}>
      <Text>{ExpoAudioFFT.hello()} tguygikuyg</Text>
      <TouchableOpacity onPress={onPickDocument}><Text>PICK FILE</Text></TouchableOpacity>
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

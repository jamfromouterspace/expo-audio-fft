import { ActivityIndicator, Alert, StyleSheet, Text, TouchableOpacity, View, useWindowDimensions } from 'react-native';
import * as ExpoAudioFFT from 'expo-audio-fft';
import * as FileSystem from "expo-file-system";
import Animated, {
  useSharedValue,
  withTiming,
  useAnimatedStyle,
  Easing,
  withSpring,
} from 'react-native-reanimated';
import { getDocumentAsync } from 'expo-document-picker';
import { useEffect, useRef, useState } from 'react';
import Slider from '@react-native-community/slider';
import * as Linking from "expo-linking"

const numBands = 60 // this must be constant

export default function App() {
  const [duration, setDuration] = useState(0)
  const [isInitialized, setIsInitialized] = useState(false)
  const [isPlaying, setIsPlaying] = useState(false)
  const [loudness2, setLoudness2] = useState(0)
  const loudness = useSharedValue(0)

  const window = useWindowDimensions()

  const url = Linking.useURL()
  useEffect(() => {
    if (url) {
      console.log("url", url)
      if (!isInitialized) {
        ExpoAudioFFT.init()
        setIsInitialized(true)
      } 
      const metadata = ExpoAudioFFT.getMetadata(url)
      console.log("metadata", metadata)
      if (!metadata.duration) {
        console.warn("ERROR: Failed to load song", metadata)
        setIsInitialized(false)
        return
      }
      setDuration(metadata.duration)
      // console.log("metadata", metadata)
      ExpoAudioFFT.load(url)
    }
  }, [url])

  const magnitudes = useRef<Animated.SharedValue<number>[]>([])
  for (let i = 0; i < numBands; i++) {
    // Replace this with your desired logic to populate the array.
    magnitudes.current[i] = useSharedValue(0)
  }
  useEffect(() =>{ 
    ExpoAudioFFT.addAudioBufferListener(event => {
      loudness.value = event.loudness*100
      // console.log("frequencies", event.bandMagnitudes.length)
      const mags = gaussianBlur(event.bandMagnitudes)
      magnitudes.current.forEach(((_, i) => {
        const prevValue = magnitudes.current[i].value
        const nextValue = mags[i]*100
        // if (Math.abs(nextValue - prevValue) < 10) {
         magnitudes.current[i].value = withTiming(nextValue, { 
          duration: 100, 
          easing: Easing.inOut(Easing.ease)
        })
        // }
      }))
    })
  }, [])
  
  const onPickDocument = async () => {
    ExpoAudioFFT.stop()
    setIsPlaying(false)
    const result = await getDocumentAsync({
      copyToCacheDirectory: true,
      multiple: false,
      type: "audio/*",
    })
    if (result.canceled) return
    console.log("initializing...")
    if (!isInitialized) {
      ExpoAudioFFT.init()
      setIsInitialized(true)
    } 
    ExpoAudioFFT.load(result.assets[0].uri)
    const metadata = ExpoAudioFFT.getMetadata(result.assets[0].uri)
    console.log("metadata", metadata)
    if (!metadata.duration) {
      console.warn("ERROR: Failed to load song", metadata)
      setIsInitialized(false)
      return
    }
    setDuration(metadata.duration)
    // console.log("metadata", metadata)
  }

  const onPickVideo = async () => {
    const result = await getDocumentAsync({
      copyToCacheDirectory: true,
      multiple: false,
      type: "video/*",
    })
  }

  const onPlayPause = () => {
    if (!isInitialized) {
      return
    }
    if (isPlaying) {
      console.log("pressing pause....")
      ExpoAudioFFT.pause()
      setIsPlaying(false)
    } else {
      console.log("pressing PLAY!!!....")
      ExpoAudioFFT.play()
      setIsPlaying(true)
    }
  }
  return (
    <View style={styles.container}>
      <TouchableOpacity 
        onPress={onPickDocument} 
        style={{ 
          backgroundColor: "black",
          padding: 12, 
          paddingLeft: 20, 
          paddingRight: 20, 
          borderRadius: 10, 
          margin: 10
        }}
      >
        <Text style={{ color: "white" }}>{"PICK FILE"}</Text>
      </TouchableOpacity>
      <TouchableOpacity 
        onPress={onPickVideo} 
        style={{ 
          backgroundColor: "black",
          padding: 12, 
          paddingLeft: 20, 
          paddingRight: 20, 
          borderRadius: 10, 
          margin: 10
        }}
      >
        <Text style={{ color: "white" }}>{"PICK VIDEO"}</Text>
      </TouchableOpacity>
      {isInitialized ? (
        <TouchableOpacity 
          onPress={onPlayPause} 
          style={{ 
            backgroundColor: "black",
            padding: 12, 
            paddingLeft: 20, 
            paddingRight: 20, 
            borderRadius: 10, 
            margin: 10
          }}
        >
          <Text style={{ color: "white" }}>{isPlaying ? "pause" : "play"}</Text>
        </TouchableOpacity>
      ) : null}
      {duration ? (
        <AudioSlider duration={duration} />
      ) : null }
      <View style={{ height: 100, width: 400, justifyContent: "flex-end", flexDirection: "row" }}>
      {/* <Animated.View style={{
        width: 10,
        height: loudness,
        backgroundColor: "green"
      }}/> */}
      {magnitudes.current.map((mag, i) => (
        <Animated.View key={i} style={{
          width: window.width/numBands,
          height: mag,
          backgroundColor: "orange"
        }} />
      ))}
      </View>
    </View>
  );
}

const AudioSlider: React.FC<{ duration: number }> = ({ duration }) => {
  const [progress, setProgress] = useState(0)
  const seeking = useRef(false)

  useEffect(() => {
    ExpoAudioFFT.addProgressListener(event => {
      if (seeking.current) return
      // console.log("currentTime", event.currentTime)
      setProgress(event.currentTime)
    })
  }, [])
  if (!duration) {
    return null
  }

  return <Slider
    style={{width: 200, height: 40}}
    minimumValue={0}
    maximumValue={duration}
    value={progress}
    onSlidingComplete={async (val) => {
      setProgress(val)
      seeking.current = true
      ExpoAudioFFT.seek(val)
      await new Promise((resolve) => setTimeout(resolve, 200))
      seeking.current = false
    }}
    minimumTrackTintColor="#FFFFFF"
    maximumTrackTintColor="#000000"
  />
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#fff',
    alignItems: 'center',
    justifyContent: 'center',
  },
});



const radius = 2
const kernel: number[] = []
// Generate the 1D Gaussian kernel
for (let x = -radius; x <= radius; x++) {
  const weight = Math.exp(-(x * x) / (2 * radius * radius))
  kernel.push(weight)
}

function gaussianBlur(data: number[]) {
  const result = []


  // Normalize the kernel
  const sum = kernel.reduce((a, b) => a + b)
  for (let i = 0; i < kernel.length; i++) {
    kernel[i] /= sum
  }

  const dataSize = data.length

  // Apply the Gaussian blur filter
  for (let i = 0; i < dataSize; i++) {
    let blurredValue = 0
    for (let j = -radius; j <= radius; j++) {
      const dataIndex = i + j
      if (dataIndex >= 0 && dataIndex < dataSize) {
        blurredValue += data[dataIndex] * kernel[j + radius]
      }
    }
    result.push(blurredValue)
  }

  return result
}
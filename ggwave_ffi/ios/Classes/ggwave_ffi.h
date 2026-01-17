#ifndef GGWAVE_FFI_H
#define GGWAVE_FFI_H

#include <stdint.h>

#if _WIN32
#define FFI_PLUGIN_EXPORT __declspec(dllexport)
#else
#define FFI_PLUGIN_EXPORT __attribute__((visibility("default"))) __attribute__((used))
#endif

#ifdef __cplusplus
extern "C" {
#endif

// Protocol IDs - must match ggwave_ProtocolId
typedef enum {
    PROTOCOL_AUDIBLE_NORMAL = 0,
    PROTOCOL_AUDIBLE_FAST = 1,
    PROTOCOL_AUDIBLE_FASTEST = 2,
    PROTOCOL_ULTRASOUND_NORMAL = 3,
    PROTOCOL_ULTRASOUND_FAST = 4,
    PROTOCOL_ULTRASOUND_FASTEST = 5,
    PROTOCOL_DT_NORMAL = 6,
    PROTOCOL_DT_FAST = 7,
    PROTOCOL_DT_FASTEST = 8,
    PROTOCOL_MT_NORMAL = 9,
    PROTOCOL_MT_FAST = 10,
    PROTOCOL_MT_FASTEST = 11,
} GGWaveProtocol;

// Sample format IDs
typedef enum {
    SAMPLE_FORMAT_U8 = 1,
    SAMPLE_FORMAT_I8 = 2,
    SAMPLE_FORMAT_U16 = 3,
    SAMPLE_FORMAT_I16 = 4,
    SAMPLE_FORMAT_F32 = 5,
} GGWaveSampleFormat;

// Operating modes
typedef enum {
    OPERATING_MODE_RX = 1 << 1,
    OPERATING_MODE_TX = 1 << 2,
    OPERATING_MODE_RX_AND_TX = (1 << 1) | (1 << 2),
} GGWaveOperatingMode;

// Instance handle
typedef int32_t GGWaveInstance;

// Initialize a new ggwave instance
// Returns instance ID or -1 on error
FFI_PLUGIN_EXPORT GGWaveInstance ggwave_ffi_init(
    float sampleRateInp,
    float sampleRateOut,
    int samplesPerFrame,
    int sampleFormatInp,
    int sampleFormatOut,
    int operatingMode
);

// Free a ggwave instance
FFI_PLUGIN_EXPORT void ggwave_ffi_free(GGWaveInstance instance);

// Encode data into audio waveform
// Returns number of bytes written to waveformBuffer, or -1 on error
// If waveformBuffer is NULL, returns the required buffer size
FFI_PLUGIN_EXPORT int32_t ggwave_ffi_encode(
    GGWaveInstance instance,
    const uint8_t* payload,
    int32_t payloadSize,
    int32_t protocol,
    int32_t volume,
    uint8_t* waveformBuffer,
    int32_t waveformBufferSize
);

// Decode audio waveform
// Returns number of bytes decoded into payloadBuffer, 0 if no message yet, or -1 on error
FFI_PLUGIN_EXPORT int32_t ggwave_ffi_decode(
    GGWaveInstance instance,
    const uint8_t* waveformBuffer,
    int32_t waveformSize,
    uint8_t* payloadBuffer,
    int32_t payloadBufferSize
);

// Get the default sample rate
FFI_PLUGIN_EXPORT float ggwave_ffi_get_default_sample_rate(void);

// Get the default samples per frame
FFI_PLUGIN_EXPORT int32_t ggwave_ffi_get_default_samples_per_frame(void);

#ifdef __cplusplus
}
#endif

#endif // GGWAVE_FFI_H

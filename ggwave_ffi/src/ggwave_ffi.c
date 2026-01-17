#include "ggwave_ffi.h"
#include "ggwave/ggwave.h"
#include <string.h>

FFI_PLUGIN_EXPORT GGWaveInstance ggwave_ffi_init(
    float sampleRateInp,
    float sampleRateOut,
    int samplesPerFrame,
    int sampleFormatInp,
    int sampleFormatOut,
    int operatingMode
) {
    ggwave_Parameters params = ggwave_getDefaultParameters();

    params.sampleRateInp = sampleRateInp;
    params.sampleRateOut = sampleRateOut;
    params.sampleRate = sampleRateInp; // Use input sample rate as operating rate
    params.samplesPerFrame = samplesPerFrame;
    params.sampleFormatInp = (ggwave_SampleFormat)sampleFormatInp;
    params.sampleFormatOut = (ggwave_SampleFormat)sampleFormatOut;
    params.operatingMode = operatingMode;

    return ggwave_init(params);
}

FFI_PLUGIN_EXPORT void ggwave_ffi_free(GGWaveInstance instance) {
    ggwave_free(instance);
}

FFI_PLUGIN_EXPORT int32_t ggwave_ffi_encode(
    GGWaveInstance instance,
    const uint8_t* payload,
    int32_t payloadSize,
    int32_t protocol,
    int32_t volume,
    uint8_t* waveformBuffer,
    int32_t waveformBufferSize
) {
    if (waveformBuffer == NULL || waveformBufferSize == 0) {
        // Query mode - return required buffer size
        return ggwave_encode(
            instance,
            payload,
            payloadSize,
            (ggwave_ProtocolId)protocol,
            volume,
            NULL,
            1  // query = 1 returns size in bytes
        );
    }

    // Encode mode
    return ggwave_encode(
        instance,
        payload,
        payloadSize,
        (ggwave_ProtocolId)protocol,
        volume,
        waveformBuffer,
        0  // query = 0 performs actual encoding
    );
}

FFI_PLUGIN_EXPORT int32_t ggwave_ffi_decode(
    GGWaveInstance instance,
    const uint8_t* waveformBuffer,
    int32_t waveformSize,
    uint8_t* payloadBuffer,
    int32_t payloadBufferSize
) {
    return ggwave_ndecode(
        instance,
        waveformBuffer,
        waveformSize,
        payloadBuffer,
        payloadBufferSize
    );
}

FFI_PLUGIN_EXPORT float ggwave_ffi_get_default_sample_rate(void) {
    return 48000.0f;
}

FFI_PLUGIN_EXPORT int32_t ggwave_ffi_get_default_samples_per_frame(void) {
    return 1024;
}

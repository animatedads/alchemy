#include <oorexxapi.h>
#include <algorithm>
#include <cstdint>
#include <stdexcept>
#include <string>
#include <vector>

namespace {
static int16_t ulawToLinear(uint8_t u) {
    u = static_cast<uint8_t>(~u);
    int t = ((u & 0x0f) << 3) + 0x84;
    t <<= (u & 0x70) >> 4;
    return static_cast<int16_t>((u & 0x80) ? (0x84 - t) : (t - 0x84));
}

static int16_t alawToLinear(uint8_t a) {
    a ^= 0x55;
    int t = (a & 0x0f) << 4;
    int segment = (a & 0x70) >> 4;
    if (segment == 0) t += 8;
    else if (segment == 1) t += 0x108;
    else { t += 0x108; t <<= segment - 1; }
    return static_cast<int16_t>((a & 0x80) ? t : -t);
}

static uint8_t linearToUlaw(int16_t sample) {
    int sign = sample < 0 ? 0x80 : 0;
    int value = sample;
    if (value < 0) value = -value;
    if (value > 32635) value = 32635;
    value += 0x84;
    int exponent = 7;
    for (int mask = 0x4000; (value & mask) == 0 && exponent > 0; mask >>= 1) exponent--;
    int mantissa = (value >> (exponent + 3)) & 0x0f;
    return static_cast<uint8_t>(~(sign | (exponent << 4) | mantissa));
}

static uint8_t linearToAlaw(int16_t sample) {
    int sign = sample < 0 ? 0x00 : 0x80;
    int value = sample;
    if (value < 0) value = -value - 1;
    if (value > 32767) value = 32767;
    int exponent = 0;
    int mantissa = 0;
    if (value >= 256) {
        int t = value >> 8;
        while (t > 1 && exponent < 7) { t >>= 1; exponent++; }
        mantissa = (value >> (exponent + 3)) & 0x0f;
    } else {
        mantissa = (value >> 4) & 0x0f;
    }
    return static_cast<uint8_t>((sign | (exponent << 4) | mantissa) ^ 0x55);
}

static RexxObjectPtr fail(RexxCallContext *context, const std::exception &error) {
    context->RaiseException1(Rexx_Error_System_service_user_defined, context->String(error.what()));
    return context->Nil();
}

static void validatePayloadType(int payloadType) {
    if (payloadType != 0 && payloadType != 8) {
        throw std::runtime_error("RTP dev2 supports payload types 0 PCMU and 8 PCMA");
    }
}
}

RexxRoutine0(CSTRING, rtp_native_version) {
    (void)context;
    return "oorexx.rtp.native/0.1-dev2";
}

RexxRoutine6(RexxObjectPtr, rtp_packet_encode,
             RexxStringObject, pcm,
             int, payloadType,
             uint32_t, sequenceValue,
             uint32_t, timestamp,
             uint32_t, ssrc,
             int, marker) {
    try {
        validatePayloadType(payloadType);
        size_t byteCount = context->StringLength(pcm);
        if ((byteCount & 1U) != 0) throw std::runtime_error("PCM payload must contain signed 16-bit little-endian samples");
        size_t samples = byteCount / 2;
        if (samples == 0) return context->Nil();
        const unsigned char *raw = reinterpret_cast<const unsigned char *>(context->StringData(pcm));
        std::vector<uint8_t> packet(12 + samples);
        uint16_t sequence = static_cast<uint16_t>(sequenceValue & 0xffffU);
        packet[0] = 0x80;
        packet[1] = static_cast<uint8_t>((marker ? 0x80 : 0x00) | (payloadType & 0x7f));
        packet[2] = static_cast<uint8_t>(sequence >> 8);
        packet[3] = static_cast<uint8_t>(sequence);
        packet[4] = static_cast<uint8_t>(timestamp >> 24);
        packet[5] = static_cast<uint8_t>(timestamp >> 16);
        packet[6] = static_cast<uint8_t>(timestamp >> 8);
        packet[7] = static_cast<uint8_t>(timestamp);
        packet[8] = static_cast<uint8_t>(ssrc >> 24);
        packet[9] = static_cast<uint8_t>(ssrc >> 16);
        packet[10] = static_cast<uint8_t>(ssrc >> 8);
        packet[11] = static_cast<uint8_t>(ssrc);
        for (size_t index = 0; index < samples; index++) {
            int16_t linear = static_cast<int16_t>(static_cast<uint16_t>(raw[2 * index]) |
                              (static_cast<uint16_t>(raw[2 * index + 1]) << 8));
            packet[12 + index] = payloadType == 0 ? linearToUlaw(linear) : linearToAlaw(linear);
        }
        return context->NewString(reinterpret_cast<const char *>(packet.data()), packet.size());
    } catch (const std::exception &error) {
        return fail(context, error);
    }
}

RexxRoutine3(RexxObjectPtr, rtp_packet_decode,
             RexxStringObject, packetObject,
             int, expectedPayloadType,
             int, maxSamples) {
    try {
        validatePayloadType(expectedPayloadType);
        const auto *packet = reinterpret_cast<const uint8_t *>(context->StringData(packetObject));
        size_t count = context->StringLength(packetObject);
        if (count < 12) return context->Nil();
        if ((packet[0] >> 6) != 2) return context->Nil();
        int csrcCount = packet[0] & 0x0f;
        bool extension = (packet[0] & 0x10) != 0;
        size_t offset = 12 + static_cast<size_t>(csrcCount) * 4;
        if (offset > count) return context->Nil();
        if (extension) {
            if (offset + 4 > count) return context->Nil();
            size_t words = (static_cast<size_t>(packet[offset + 2]) << 8) | packet[offset + 3];
            offset += 4 + words * 4;
            if (offset > count) return context->Nil();
        }
        int payloadType = packet[1] & 0x7f;
        if (payloadType != expectedPayloadType) return context->Nil();
        validatePayloadType(payloadType);
        size_t available = count - offset;
        size_t limit = static_cast<size_t>(std::max(0, maxSamples));
        size_t samples = std::min(available, limit);
        std::string pcm(samples * 2, '\0');
        for (size_t index = 0; index < samples; index++) {
            int16_t linear = payloadType == 0 ? ulawToLinear(packet[offset + index]) : alawToLinear(packet[offset + index]);
            pcm[2 * index] = static_cast<char>(linear & 0xff);
            pcm[2 * index + 1] = static_cast<char>((static_cast<uint16_t>(linear) >> 8) & 0xff);
        }
        uint16_t sequence = static_cast<uint16_t>((static_cast<uint16_t>(packet[2]) << 8) | packet[3]);
        uint32_t timestamp = (static_cast<uint32_t>(packet[4]) << 24) |
                             (static_cast<uint32_t>(packet[5]) << 16) |
                             (static_cast<uint32_t>(packet[6]) << 8) | packet[7];
        uint32_t ssrc = (static_cast<uint32_t>(packet[8]) << 24) |
                        (static_cast<uint32_t>(packet[9]) << 16) |
                        (static_cast<uint32_t>(packet[10]) << 8) | packet[11];
        auto result = context->NewArray(9);
        context->ArrayPut(result, context->NewString(pcm.data(), pcm.size()), 1);
        context->ArrayPut(result, context->UnsignedInt32ToObject(sequence), 2);
        context->ArrayPut(result, context->UnsignedInt32ToObject(timestamp), 3);
        context->ArrayPut(result, context->UnsignedInt32ToObject(ssrc), 4);
        context->ArrayPut(result, context->Int32ToObject(payloadType), 5);
        context->ArrayPut(result, context->Int32ToObject((packet[1] & 0x80) ? 1 : 0), 6);
        context->ArrayPut(result, context->Int32ToObject(static_cast<int>(samples)), 7);
        context->ArrayPut(result, context->Int32ToObject(8000), 8);
        context->ArrayPut(result, context->String("S16LE"), 9);
        return result;
    } catch (const std::exception &error) {
        return fail(context, error);
    }
}

RexxRoutineEntry rtp_routines[] = {
    REXX_TYPED_ROUTINE(rtp_native_version, rtp_native_version),
    REXX_TYPED_ROUTINE(rtp_packet_encode, rtp_packet_encode),
    REXX_TYPED_ROUTINE(rtp_packet_decode, rtp_packet_decode),
    REXX_LAST_ROUTINE()
};

RexxPackageEntry oorexx_rtp_package_entry = {
    STANDARD_PACKAGE_HEADER REXX_INTERPRETER_5_0_0,
    "oorexx_rtp",
    "0.1-dev2",
    NULL,
    NULL,
    rtp_routines,
    NULL
};
OOREXX_GET_PACKAGE(oorexx_rtp);

#include <oorexxapi.h>
#include <oorexxerrors.h>
#include "xtp/xtp_socket.hpp"
#include <atomic>
#include <cstdint>
#include <memory>
#include <mutex>
#include <stdexcept>
#include <string>
#include <unordered_map>
#include <vector>

namespace {
std::mutex g_lock;
std::unordered_map<uint64_t, std::unique_ptr<xtp::Listener>> g_listeners;
std::unordered_map<uint64_t, std::unique_ptr<xtp::MultipathListener>> g_multipath_listeners;
std::unordered_map<uint64_t, std::unique_ptr<xtp::MulticastListener>> g_multicast_listeners;
std::atomic<uint64_t> g_next{1};

void raise_error(RexxCallContext *context, const std::string &s) {
    context->RaiseException1(Rexx_Error_System_service_user_defined,
                             context->NewStringFromAsciiz(s.c_str()));
}

xtp::Listener *listener_for(uint64_t handle) {
    auto it = g_listeners.find(handle);
    if (it == g_listeners.end()) return nullptr;
    return it->second.get();
}
xtp::MulticastListener *multicast_listener_for(uint64_t handle) {
    auto it = g_multicast_listeners.find(handle);
    if (it == g_multicast_listeners.end()) return nullptr;
    return it->second.get();
}
xtp::MultipathListener *multipath_listener_for(uint64_t handle) {
    auto it = g_multipath_listeners.find(handle);
    if (it == g_multipath_listeners.end()) return nullptr;
    return it->second.get();
}
}

RexxRoutine2(uint64_t, xtpNativeListenerOpen,
             CSTRING, peer,
             OPTIONAL_int, timeoutMs)
{
    try {
        xtp::ListenOptions options;
        if (argumentExists(2)) options.timeout_ms = timeoutMs;
        xtp::SocketProvider provider;
        auto listener = provider.listen(peer ? peer : "", options);
        const uint64_t handle = g_next.fetch_add(1);
        std::lock_guard<std::mutex> guard(g_lock);
        g_listeners.emplace(handle, std::move(listener));
        return handle;
    } catch (const std::exception &e) {
        raise_error(context, std::string("XTP listener open: ") + e.what());
        return 0;
    }
}

RexxRoutine1(RexxObjectPtr, xtpNativeListenerReceive,
             uint64_t, handle)
{
    try {
        xtp::Listener *listener = nullptr;
        {
            std::lock_guard<std::mutex> guard(g_lock);
            listener = listener_for(handle);
        }
        if (!listener) throw std::runtime_error("unknown listener handle");
        auto r = listener->receive();
        return context->NewString(reinterpret_cast<const char *>(r.logical.data()), r.logical.size());
    } catch (const std::exception &e) {
        raise_error(context, std::string("XTP listener receive: ") + e.what());
        return NULLOBJECT;
    }
}

RexxRoutine1(int, xtpNativeListenerClose,
             uint64_t, handle)
{
    try {
        std::unique_ptr<xtp::Listener> listener;
        {
            std::lock_guard<std::mutex> guard(g_lock);
            auto it = g_listeners.find(handle);
            if (it == g_listeners.end()) return 0;
            listener = std::move(it->second);
            g_listeners.erase(it);
        }
        listener->close();
        return 0;
    } catch (const std::exception &e) {
        raise_error(context, std::string("XTP listener close: ") + e.what());
        return -1;
    }
}

RexxRoutine2(int, xtpNativeSend,
             CSTRING, peer,
             RexxStringObject, bytes)
{
    try {
        const char *p = context->StringData(bytes);
        const size_t n = context->StringLength(bytes);
        std::vector<uint8_t> data(reinterpret_cast<const uint8_t *>(p),
                                  reinterpret_cast<const uint8_t *>(p) + n);
        xtp::SocketProvider provider;
        provider.send(peer ? peer : "", data);
        if (n > static_cast<size_t>(INT32_MAX)) throw std::runtime_error("payload too large for Rexx send result");
        return static_cast<int>(n);
    } catch (const std::exception &e) {
        raise_error(context, std::string("XTP send: ") + e.what());
        return -1;
    }
}



RexxRoutine2(uint64_t, xtpNativeMulticastListenerOpen,
             CSTRING, peer,
             OPTIONAL_int, timeoutMs)
{
    try {
        xtp::ListenOptions options;
        if (argumentExists(2)) options.timeout_ms = timeoutMs;
        xtp::SocketProvider provider;
        auto listener = provider.listen_multicast(peer ? peer : "", options);
        const uint64_t handle = g_next.fetch_add(1);
        std::lock_guard<std::mutex> guard(g_lock);
        g_multicast_listeners.emplace(handle, std::move(listener));
        return handle;
    } catch (const std::exception &e) {
        raise_error(context, std::string("XTP multicast listener open: ") + e.what());
        return 0;
    }
}

RexxRoutine4(uint64_t, xtpNativeMulticastListenerOpenEx,
             CSTRING, peer,
             int, timeoutMs,
             int, receiveWindow,
             int, rejectSuppressionMs)
{
    try {
        if (receiveWindow < 1) throw std::runtime_error("receiveWindow must be positive");
        if (rejectSuppressionMs < 0) throw std::runtime_error("rejectSuppressionMs must not be negative");
        xtp::ListenOptions options;
        options.timeout_ms = timeoutMs;
        options.receive_window = static_cast<uint32_t>(receiveWindow);
        options.reject_suppression_ms = rejectSuppressionMs;
        xtp::SocketProvider provider;
        auto listener = provider.listen_multicast(peer ? peer : "", options);
        const uint64_t handle = g_next.fetch_add(1);
        std::lock_guard<std::mutex> guard(g_lock);
        g_multicast_listeners.emplace(handle, std::move(listener));
        return handle;
    } catch (const std::exception &e) {
        raise_error(context, std::string("XTP multicast listener open: ") + e.what());
        return 0;
    }
}

RexxRoutine6(uint64_t, xtpNativeMulticastListenerOpenRate,
             CSTRING, peer,
             int, timeoutMs,
             int, receiveWindow,
             int, rejectSuppressionMs,
             uint32_t, advertisedRate,
             uint32_t, advertisedBurst)
{
    try {
        if (receiveWindow < 1) throw std::runtime_error("receiveWindow must be positive");
        if (rejectSuppressionMs < 0) throw std::runtime_error("rejectSuppressionMs must not be negative");
        if (advertisedRate == 0) throw std::runtime_error("advertisedRate must be positive or 0xffffffff");
        if (advertisedBurst == 0) throw std::runtime_error("advertisedBurst must be positive");
        xtp::ListenOptions options;
        options.timeout_ms = timeoutMs;
        options.receive_window = static_cast<uint32_t>(receiveWindow);
        options.reject_suppression_ms = rejectSuppressionMs;
        options.advertised_rate_bytes_per_sec = advertisedRate;
        options.advertised_burst_bytes = advertisedBurst;
        xtp::SocketProvider provider;
        auto listener = provider.listen_multicast(peer ? peer : "", options);
        const uint64_t handle = g_next.fetch_add(1);
        std::lock_guard<std::mutex> guard(g_lock);
        g_multicast_listeners.emplace(handle, std::move(listener));
        return handle;
    } catch (const std::exception &e) {
        raise_error(context, std::string("XTP multicast listener open: ") + e.what());
        return 0;
    }
}

RexxRoutine1(RexxObjectPtr, xtpNativeMulticastListenerReceive,
             uint64_t, handle)
{
    try {
        xtp::MulticastListener *listener = nullptr;
        { std::lock_guard<std::mutex> guard(g_lock); listener = multicast_listener_for(handle); }
        if (!listener) throw std::runtime_error("unknown multicast listener handle");
        auto r = listener->receive();
        return context->NewString(reinterpret_cast<const char *>(r.logical.data()), r.logical.size());
    } catch (const std::exception &e) {
        raise_error(context, std::string("XTP multicast listener receive: ") + e.what());
        return NULLOBJECT;
    }
}

RexxRoutine1(int, xtpNativeMulticastListenerClose,
             uint64_t, handle)
{
    try {
        std::unique_ptr<xtp::MulticastListener> listener;
        { std::lock_guard<std::mutex> guard(g_lock); auto it=g_multicast_listeners.find(handle); if(it==g_multicast_listeners.end()) return 0; listener=std::move(it->second); g_multicast_listeners.erase(it); }
        listener->close(); return 0;
    } catch (const std::exception &e) {
        raise_error(context, std::string("XTP multicast listener close: ") + e.what()); return -1;
    }
}

RexxRoutine4(int, xtpNativeMulticastSend,
             CSTRING, peer,
             RexxStringObject, bytes,
             int, expectedReceivers,
             int, reliable)
{
    try {
        if(expectedReceivers < 0) throw std::runtime_error("expectedReceivers must not be negative");
        const char *p=context->StringData(bytes); const size_t n=context->StringLength(bytes);
        std::vector<uint8_t> data(reinterpret_cast<const uint8_t *>(p), reinterpret_cast<const uint8_t *>(p)+n);
        xtp::MulticastOptions options; options.expected_receivers=static_cast<size_t>(expectedReceivers); options.reliable=(reliable!=0);
        xtp::SocketProvider provider; provider.send_multicast(peer?peer:"",data,options);
        if(n>static_cast<size_t>(INT32_MAX)) throw std::runtime_error("payload too large for Rexx send result");
        return static_cast<int>(n);
    } catch (const std::exception &e) {
        raise_error(context, std::string("XTP multicast send: ") + e.what()); return -1;
    }
}

RexxRoutine8(int, xtpNativeMulticastSendEx,
             CSTRING, peer,
             RexxStringObject, bytes,
             int, expectedReceivers,
             int, reliable,
             int, segmentBytes,
             int, timeoutMs,
             int, retries,
             int, allocationPacing)
{
    try {
        if(expectedReceivers < 0) throw std::runtime_error("expectedReceivers must not be negative");
        if(segmentBytes < 64) throw std::runtime_error("segmentBytes must be at least 64");
        if(retries < 1) throw std::runtime_error("retries must be positive");
        const char *p=context->StringData(bytes); const size_t n=context->StringLength(bytes);
        std::vector<uint8_t> data(reinterpret_cast<const uint8_t *>(p), reinterpret_cast<const uint8_t *>(p)+n);
        xtp::MulticastOptions options;
        options.expected_receivers=static_cast<size_t>(expectedReceivers);
        options.reliable=(reliable!=0);
        options.segment_bytes=static_cast<size_t>(segmentBytes);
        options.timeout_ms=timeoutMs;
        options.retries=retries;
        options.allocation_pacing=(allocationPacing!=0);
        xtp::SocketProvider provider; provider.send_multicast(peer?peer:"",data,options);
        if(n>static_cast<size_t>(INT32_MAX)) throw std::runtime_error("payload too large for Rexx send result");
        return static_cast<int>(n);
    } catch (const std::exception &e) {
        raise_error(context, std::string("XTP multicast send: ") + e.what()); return -1;
    }
}

RexxRoutine9(int, xtpNativeMulticastSendRate,
             CSTRING, peer,
             RexxStringObject, bytes,
             int, expectedReceivers,
             int, reliable,
             int, segmentBytes,
             int, timeoutMs,
             int, retries,
             int, allocationPacing,
             int, ratePacing)
{
    try {
        if(expectedReceivers < 0) throw std::runtime_error("expectedReceivers must not be negative");
        if(segmentBytes < 64) throw std::runtime_error("segmentBytes must be at least 64");
        if(retries < 1) throw std::runtime_error("retries must be positive");
        const char *p=context->StringData(bytes); const size_t n=context->StringLength(bytes);
        std::vector<uint8_t> data(reinterpret_cast<const uint8_t *>(p), reinterpret_cast<const uint8_t *>(p)+n);
        xtp::MulticastOptions options;
        options.expected_receivers=static_cast<size_t>(expectedReceivers);
        options.reliable=(reliable!=0);
        options.segment_bytes=static_cast<size_t>(segmentBytes);
        options.timeout_ms=timeoutMs;
        options.retries=retries;
        options.allocation_pacing=(allocationPacing!=0);
        options.rate_pacing=(ratePacing!=0);
        xtp::SocketProvider provider; provider.send_multicast(peer?peer:"",data,options);
        if(n>static_cast<size_t>(INT32_MAX)) throw std::runtime_error("payload too large for Rexx send result");
        return static_cast<int>(n);
    } catch (const std::exception &e) {
        raise_error(context, std::string("XTP multicast send: ") + e.what()); return -1;
    }
}

RexxRoutine3(uint64_t, xtpNativeMultipathListenerOpen,
             CSTRING, peer,
             int, maxPaths,
             OPTIONAL_int, timeoutMs)
{
    try {
        if (maxPaths < 1) throw std::runtime_error("maxPaths must be positive");
        xtp::ListenOptions options;
        if (argumentExists(3)) options.timeout_ms = timeoutMs;
        xtp::SocketProvider provider;
        auto listener = provider.listen_multipath(peer ? peer : "", static_cast<size_t>(maxPaths), options);
        const uint64_t handle = g_next.fetch_add(1);
        std::lock_guard<std::mutex> guard(g_lock);
        g_multipath_listeners.emplace(handle, std::move(listener));
        return handle;
    } catch (const std::exception &e) {
        raise_error(context, std::string("XTP multipath listener open: ") + e.what());
        return 0;
    }
}

RexxRoutine1(RexxObjectPtr, xtpNativeMultipathListenerReceive,
             uint64_t, handle)
{
    try {
        xtp::MultipathListener *listener = nullptr;
        {
            std::lock_guard<std::mutex> guard(g_lock);
            listener = multipath_listener_for(handle);
        }
        if (!listener) throw std::runtime_error("unknown multipath listener handle");
        auto r = listener->receive();
        return context->NewString(reinterpret_cast<const char *>(r.logical.data()), r.logical.size());
    } catch (const std::exception &e) {
        raise_error(context, std::string("XTP multipath listener receive: ") + e.what());
        return NULLOBJECT;
    }
}

RexxRoutine1(int, xtpNativeMultipathListenerClose,
             uint64_t, handle)
{
    try {
        std::unique_ptr<xtp::MultipathListener> listener;
        {
            std::lock_guard<std::mutex> guard(g_lock);
            auto it = g_multipath_listeners.find(handle);
            if (it == g_multipath_listeners.end()) return 0;
            listener = std::move(it->second);
            g_multipath_listeners.erase(it);
        }
        listener->close();
        return 0;
    } catch (const std::exception &e) {
        raise_error(context, std::string("XTP multipath listener close: ") + e.what());
        return -1;
    }
}

RexxRoutine5(int, xtpNativeMultipathSend,
             CSTRING, peer,
             RexxStringObject, bytes,
             int, chunkBytes,
             int, maxPaths,
             int, generation)
{
    try {
        if (chunkBytes < 1 || maxPaths < 1 || generation < 0)
            throw std::runtime_error("invalid multipath options");
        const char *p = context->StringData(bytes);
        const size_t n = context->StringLength(bytes);
        std::vector<uint8_t> data(reinterpret_cast<const uint8_t *>(p),
                                  reinterpret_cast<const uint8_t *>(p) + n);
        xtp::MultipathOptions options;
        options.chunk_bytes = static_cast<size_t>(chunkBytes);
        options.max_paths = static_cast<size_t>(maxPaths);
        options.generation = static_cast<uint32_t>(generation);
        xtp::SocketProvider provider;
        provider.send_multipath(peer ? peer : "", data, options);
        if (n > static_cast<size_t>(INT32_MAX)) throw std::runtime_error("payload too large for Rexx send result");
        return static_cast<int>(n);
    } catch (const std::exception &e) {
        raise_error(context, std::string("XTP multipath send: ") + e.what());
        return -1;
    }
}

RexxRoutineEntry xtp_native_routines[] = {
    REXX_TYPED_ROUTINE(xtpNativeListenerOpen, xtpNativeListenerOpen),
    REXX_TYPED_ROUTINE(xtpNativeListenerReceive, xtpNativeListenerReceive),
    REXX_TYPED_ROUTINE(xtpNativeListenerClose, xtpNativeListenerClose),
    REXX_TYPED_ROUTINE(xtpNativeSend, xtpNativeSend),
    REXX_TYPED_ROUTINE(xtpNativeMulticastListenerOpen, xtpNativeMulticastListenerOpen),
    REXX_TYPED_ROUTINE(xtpNativeMulticastListenerOpenEx, xtpNativeMulticastListenerOpenEx),
    REXX_TYPED_ROUTINE(xtpNativeMulticastListenerOpenRate, xtpNativeMulticastListenerOpenRate),
    REXX_TYPED_ROUTINE(xtpNativeMulticastListenerReceive, xtpNativeMulticastListenerReceive),
    REXX_TYPED_ROUTINE(xtpNativeMulticastListenerClose, xtpNativeMulticastListenerClose),
    REXX_TYPED_ROUTINE(xtpNativeMulticastSend, xtpNativeMulticastSend),
    REXX_TYPED_ROUTINE(xtpNativeMulticastSendEx, xtpNativeMulticastSendEx),
    REXX_TYPED_ROUTINE(xtpNativeMulticastSendRate, xtpNativeMulticastSendRate),
    REXX_TYPED_ROUTINE(xtpNativeMultipathListenerOpen, xtpNativeMultipathListenerOpen),
    REXX_TYPED_ROUTINE(xtpNativeMultipathListenerReceive, xtpNativeMultipathListenerReceive),
    REXX_TYPED_ROUTINE(xtpNativeMultipathListenerClose, xtpNativeMultipathListenerClose),
    REXX_TYPED_ROUTINE(xtpNativeMultipathSend, xtpNativeMultipathSend),
    REXX_LAST_ROUTINE()
};

RexxPackageEntry oorexx_xtp_native_package_entry = {
    STANDARD_PACKAGE_HEADER
    REXX_INTERPRETER_5_0_0,
    "oorexx_xtp_native",
    "0.1-dev17",
    nullptr,
    nullptr,
    xtp_native_routines,
    nullptr
};

OOREXX_GET_PACKAGE(oorexx_xtp_native);

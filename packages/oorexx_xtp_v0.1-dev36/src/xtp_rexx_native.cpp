#include <oorexxapi.h>
#include <oorexxerrors.h>
#include "xtp/xtp_socket.hpp"
#include "xtp/xtp_session.hpp"
#include "xtp/xtp_security.hpp"
#include <openssl/crypto.h>
#include <cstdio>
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
std::unordered_map<uint64_t, std::string> g_last_service;
std::unordered_map<uint64_t, std::string> g_last_protection;   // dev33: "protection keyIdHex principal|-"
std::unordered_map<uint64_t, std::string> g_last_mp_protection; // dev34: multipath "protection keyIdHex service|-"
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
xtp::PrioritySpec priority_spec(const char *spec){
    xtp::PrioritySpec p; if(!spec||!*spec)return p; std::string s(spec);
    if(s=="disabled"||s=="none"||s=="off")return p;
    auto k=s.find(":"); if(k==std::string::npos)throw std::runtime_error("priority spec must be static:N or deadline:N");
    p.mode=xtp::parse_priority_mode(s.substr(0,k)); p.sort=uint32_t(std::stoul(s.substr(k+1))); return p;
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


RexxRoutine3(uint64_t, xtpNativeListenerOpenRoute,
             CSTRING, peer,
             OPTIONAL_int, timeoutMs,
             uint32_t, exchangeRoute)
{
    try {
        xtp::ListenOptions options;
        if (argumentExists(2)) options.timeout_ms = timeoutMs;
        options.exchange_route_value = exchangeRoute;
        xtp::SocketProvider provider;
        auto listener = provider.listen(peer ? peer : "", options);
        const uint64_t handle = g_next.fetch_add(1);
        std::lock_guard<std::mutex> guard(g_lock);
        g_listeners.emplace(handle, std::move(listener));
        return handle;
    } catch (const std::exception &e) {
        raise_error(context, std::string("XTP route listener open: ") + e.what());
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
        { std::lock_guard<std::mutex> guard(g_lock); g_last_service[handle]=r.service_name;
          char kid[17];std::snprintf(kid,sizeof kid,"%016llx",(unsigned long long)r.key_id);
          g_last_protection[handle]=std::string(xtp::protection_name(r.protection))+" "+(r.key_id?kid:"-")+" "+(r.key_principal.empty()?"-":r.key_principal); }
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
            g_last_service.erase(handle);g_last_protection.erase(handle);
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




RexxRoutine3(int, xtpNativeSendService,
             CSTRING, peer,
             RexxStringObject, bytes,
             CSTRING, serviceName)
{
    try {
        const char *p=context->StringData(bytes); const size_t n=context->StringLength(bytes);
        std::vector<uint8_t> data(reinterpret_cast<const uint8_t *>(p),reinterpret_cast<const uint8_t *>(p)+n);
        xtp::SendOptions options; options.service_name=serviceName?serviceName:"";
        if(options.service_name.empty()) throw std::runtime_error("named service must not be empty");
        xtp::SocketProvider provider; provider.send(peer?peer:"",data,options);
        if(n>static_cast<size_t>(INT32_MAX)) throw std::runtime_error("payload too large for Rexx send result");
        return static_cast<int>(n);
    } catch(const std::exception&e){raise_error(context,std::string("XTP named-service send: ")+e.what());return -1;}
}

RexxRoutine5(int, xtpNativeSendServicePriority,
             CSTRING, peer,
             RexxStringObject, bytes,
             CSTRING, serviceName,
             CSTRING, priorityMode,
             uint32_t, sortValue)
{
    try {
        const char *p=context->StringData(bytes); const size_t n=context->StringLength(bytes);
        std::vector<uint8_t> data(reinterpret_cast<const uint8_t *>(p),reinterpret_cast<const uint8_t *>(p)+n);
        xtp::SendOptions options; options.service_name=serviceName?serviceName:"";
        if(!xtp::valid_service_name(options.service_name)) throw std::runtime_error("invalid named service");
        options.priority.mode=xtp::parse_priority_mode(priorityMode?priorityMode:"disabled"); options.priority.sort=sortValue;
        xtp::SocketProvider provider; provider.send(peer?peer:"",data,options);
        if(n>static_cast<size_t>(INT32_MAX)) throw std::runtime_error("payload too large for Rexx send result");
        return static_cast<int>(n);
    } catch(const std::exception&e){raise_error(context,std::string("XTP named-service priority send: ")+e.what());return -1;}
}

RexxRoutine6(int, xtpNativeSendServicePriorityRate,
             CSTRING, peer,
             RexxStringObject, bytes,
             CSTRING, serviceName,
             CSTRING, priorityMode,
             uint32_t, sortValue,
             uint64_t, maxRateBytesPerSec)
{
    try {
        if(maxRateBytesPerSec==0) throw std::runtime_error("max rate must be positive");
        const char *p=context->StringData(bytes); const size_t n=context->StringLength(bytes);
        std::vector<uint8_t> data(reinterpret_cast<const uint8_t *>(p),reinterpret_cast<const uint8_t *>(p)+n);
        xtp::SendOptions options; options.service_name=serviceName?serviceName:"";
        if(!xtp::valid_service_name(options.service_name)) throw std::runtime_error("invalid named service");
        options.priority.mode=xtp::parse_priority_mode(priorityMode?priorityMode:"disabled"); options.priority.sort=sortValue;
        options.max_rate_bytes_per_sec=maxRateBytesPerSec;
        xtp::SocketProvider provider; provider.send(peer?peer:"",data,options);
        if(n>static_cast<size_t>(INT32_MAX)) throw std::runtime_error("payload too large for Rexx send result");
        return static_cast<int>(n);
    } catch(const std::exception&e){raise_error(context,std::string("XTP named-service rate send: ")+e.what());return -1;}
}

RexxRoutine3(uint64_t, xtpNativeListenerOpenServices,
             CSTRING, peer,
             OPTIONAL_int, timeoutMs,
             CSTRING, serviceList)
{
    try {
        xtp::ListenOptions options;
        if(argumentExists(2)) options.timeout_ms=timeoutMs;
        std::string list=serviceList?serviceList:"";
        size_t pos=0;
        while(pos<=list.size()){
            auto comma=list.find(',',pos);auto item=list.substr(pos,comma==std::string::npos?std::string::npos:comma-pos);
            if(!item.empty()){if(!xtp::valid_service_name(item))throw std::runtime_error("invalid allowed service: "+item);options.allowed_services.push_back(item);}
            if (comma == std::string::npos) {
                break;
            }
            pos = comma + 1;
        }
        if(options.allowed_services.empty()) throw std::runtime_error("at least one allowed service is required");
        xtp::SocketProvider provider;auto listener=provider.listen(peer?peer:"",options);
        const uint64_t handle=g_next.fetch_add(1);
        std::lock_guard<std::mutex> guard(g_lock);g_listeners.emplace(handle,std::move(listener));
        return handle;
    } catch(const std::exception&e){raise_error(context,std::string("XTP named-service listener open: ")+e.what());return 0;}
}

RexxRoutine1(RexxStringObject, xtpNativeListenerLastService,
             uint64_t, handle)
{
    std::lock_guard<std::mutex> guard(g_lock);
    auto it=g_last_service.find(handle);
    if(it==g_last_service.end()) return context->NewStringFromAsciiz("");
    return context->NewStringFromAsciiz(it->second.c_str());
}

// dev33: how the last message received on this listener was protected:
// "none - -", or "authenticate|encrypt keyIdHex principal|-".
RexxRoutine1(RexxStringObject, xtpNativeListenerLastProtection,
             uint64_t, handle)
{
    std::lock_guard<std::mutex> guard(g_lock);
    auto it=g_last_protection.find(handle);
    if(it==g_last_protection.end()) return context->NewStringFromAsciiz("none - -");
    return context->NewStringFromAsciiz(it->second.c_str());
}

RexxRoutine3(uint32_t, xtpNativeSendRoute,
             CSTRING, peer,
             RexxStringObject, bytes,
             uint32_t, routeValue)
{
    try {
        const char *p = context->StringData(bytes);
        const size_t n = context->StringLength(bytes);
        std::vector<uint8_t> data(reinterpret_cast<const uint8_t *>(p),
                                  reinterpret_cast<const uint8_t *>(p) + n);
        xtp::SendOptions options; options.route_value = routeValue;
        xtp::SocketProvider provider;
        auto result = provider.send(peer ? peer : "", data, options);
        return result.peer_xroute;
    } catch (const std::exception &e) {
        raise_error(context, std::string("XTP route send: ") + e.what());
        return 0;
    }
}

RexxRoutine4(int, xtpNativeSendPriority,
             CSTRING, peer,
             RexxStringObject, bytes,
             CSTRING, priorityMode,
             uint32_t, sortValue)
{
    try {
        const char *p=context->StringData(bytes); const size_t n=context->StringLength(bytes);
        std::vector<uint8_t> data(reinterpret_cast<const uint8_t *>(p),reinterpret_cast<const uint8_t *>(p)+n);
        xtp::SendOptions options; options.priority.mode=xtp::parse_priority_mode(priorityMode?priorityMode:"disabled"); options.priority.sort=sortValue;
        xtp::SocketProvider provider; provider.send(peer?peer:"",data,options);
        if(n>static_cast<size_t>(INT32_MAX))throw std::runtime_error("payload too large for Rexx send result");
        return static_cast<int>(n);
    } catch(const std::exception &e){raise_error(context,std::string("XTP priority send: ")+e.what());return -1;}
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


RexxRoutine10(int, xtpNativeMulticastSendPriority,
             CSTRING, peer, RexxStringObject, bytes, int, expectedReceivers, int, reliable,
             int, segmentBytes, int, timeoutMs, int, retries, int, allocationPacing, int, ratePacing, CSTRING, prioritySpec)
{
    try {
        if(expectedReceivers<0)throw std::runtime_error("expectedReceivers must not be negative");
        if(segmentBytes<64)throw std::runtime_error("segmentBytes must be at least 64");
        if(retries<1)throw std::runtime_error("retries must be positive");
        const char *p=context->StringData(bytes); const size_t n=context->StringLength(bytes);
        std::vector<uint8_t> data(reinterpret_cast<const uint8_t *>(p),reinterpret_cast<const uint8_t *>(p)+n);
        xtp::MulticastOptions options; options.expected_receivers=static_cast<size_t>(expectedReceivers);options.reliable=(reliable!=0);options.segment_bytes=static_cast<size_t>(segmentBytes);options.timeout_ms=timeoutMs;options.retries=retries;options.allocation_pacing=(allocationPacing!=0);options.rate_pacing=(ratePacing!=0);options.priority=priority_spec(prioritySpec);
        xtp::SocketProvider provider;provider.send_multicast(peer?peer:"",data,options);
        if(n>static_cast<size_t>(INT32_MAX)) throw std::runtime_error("payload too large for Rexx send result");
        return static_cast<int>(n);
    } catch(const std::exception &e){raise_error(context,std::string("XTP multicast priority send: ")+e.what());return -1;}
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
        { std::lock_guard<std::mutex> guard(g_lock);
          char kid[17];std::snprintf(kid,sizeof kid,"%016llx",(unsigned long long)r.key_id);
          g_last_mp_protection[handle]=std::string(xtp::protection_name(r.protection))+" "+(r.key_id?kid:"-")+" "+(r.service_name.empty()?"-":r.service_name); }
        return context->NewString(reinterpret_cast<const char *>(r.logical.data()), r.logical.size());
    } catch (const std::exception &e) {
        raise_error(context, std::string("XTP multipath listener receive: ") + e.what());
        return NULLOBJECT;
    }
}

// dev34: how the last multipath transfer received on this listener was
// protected: "none - -", or "authenticate|encrypt keyIdHex service".
RexxRoutine1(RexxStringObject, xtpNativeMultipathLastProtection,
             uint64_t, handle)
{
    std::lock_guard<std::mutex> guard(g_lock);
    auto it=g_last_mp_protection.find(handle);
    if(it==g_last_mp_protection.end()) return context->NewStringFromAsciiz("none - -");
    return context->NewStringFromAsciiz(it->second.c_str());
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

// dev34: optional serviceName.  A named service with a profile is sent
// protected, chunk by chunk, like any message to that service.
RexxRoutine6(int, xtpNativeMultipathSend,
             CSTRING, peer,
             RexxStringObject, bytes,
             int, chunkBytes,
             int, maxPaths,
             int, generation,
             OPTIONAL_CSTRING, serviceName)
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
        if (serviceName && *serviceName) {
            if (!xtp::valid_service_name(serviceName)) throw std::runtime_error("invalid named service");
            options.send.service_name = serviceName;
        }
        xtp::SocketProvider provider;
        provider.send_multipath(peer ? peer : "", data, options);
        if (n > static_cast<size_t>(INT32_MAX)) throw std::runtime_error("payload too large for Rexx send result");
        return static_cast<int>(n);
    } catch (const std::exception &e) {
        raise_error(context, std::string("XTP multipath send: ") + e.what());
        return -1;
    }
}


// ---------------------------------------------------------------------------
// dev31: interactive contexts (xtp/xtp_session.hpp) for ooRexx.
// Handles are kept as shared_ptr so a blocking read, write or accept on one
// ooRexx thread is safe while another thread closes the same handle.
// ---------------------------------------------------------------------------
namespace {
std::unordered_map<uint64_t, std::shared_ptr<xtp::Session>> g_sessions;
std::unordered_map<uint64_t, std::shared_ptr<xtp::SessionListener>> g_session_listeners;
std::shared_ptr<xtp::Session> session_for(uint64_t h){
    std::lock_guard<std::mutex> guard(g_lock);
    auto it=g_sessions.find(h); if(it==g_sessions.end()) throw std::runtime_error("unknown XTP session handle");
    return it->second;
}
uint64_t keep_session(std::unique_ptr<xtp::Session> s){
    const uint64_t h=g_next.fetch_add(1);
    std::lock_guard<std::mutex> guard(g_lock); g_sessions.emplace(h,std::shared_ptr<xtp::Session>(std::move(s)));
    return h;
}
xtp::Route route_for_peer(const char *peer){
    xtp::SocketProvider provider;
    auto sel=provider.select(peer?peer:"");
    if(!sel) throw std::runtime_error(std::string("no XTP route for peer ")+(peer?peer:""));
    return sel->route;
}
std::string key_hex(uint64_t v){char b[17];std::snprintf(b,sizeof b,"%016llx",(unsigned long long)v);return b;}
std::vector<std::string> split_services(const char *list){
    std::vector<std::string> out; if(!list) return out; std::string v(list); size_t p0=0;
    for(;;){auto c=v.find(',',p0);auto item=v.substr(p0,c==std::string::npos?std::string::npos:c-p0);if(!item.empty())out.push_back(item);if(c==std::string::npos)break;p0=c+1;}
    return out;
}
}

// Listen for interactive contexts on the route of peer.  services: empty = any,
// otherwise a comma-separated list of admitted named services.
// dev32: requireProtection = 1 refuses unprotected opens even of services without keys.
RexxRoutine3(uint64_t, xtpNativeSessionListen,
             CSTRING, peer,
             OPTIONAL_CSTRING, services,
             OPTIONAL_int, requireProtection)
{
    try {
        xtp::SessionListenOptions o; o.allowed_services=split_services(services);
        if(argumentExists(3)) o.require_protection=requireProtection!=0;
        auto l=std::make_shared<xtp::SessionListener>(route_for_peer(peer),o);
        const uint64_t h=g_next.fetch_add(1);
        std::lock_guard<std::mutex> guard(g_lock); g_session_listeners.emplace(h,l);
        return h;
    } catch (const std::exception &e) { raise_error(context, std::string("XTP session listen: ")+e.what()); return 0; }
}

// The next session, or 0 on timeout.  timeoutMs < 0 waits.
RexxRoutine2(uint64_t, xtpNativeSessionAccept,
             uint64_t, handle,
             OPTIONAL_int, timeoutMs)
{
    try {
        std::shared_ptr<xtp::SessionListener> l;
        { std::lock_guard<std::mutex> guard(g_lock); auto it=g_session_listeners.find(handle); if(it!=g_session_listeners.end()) l=it->second; }
        if(!l) throw std::runtime_error("unknown XTP session listener handle");
        auto s=l->accept(argumentExists(2)?timeoutMs:-1);
        if(!s) return 0;
        return keep_session(std::move(s));
    } catch (const std::exception &e) { raise_error(context, std::string("XTP session accept: ")+e.what()); return 0; }
}

RexxRoutine1(int, xtpNativeSessionListenerClose,
             uint64_t, handle)
{
    std::shared_ptr<xtp::SessionListener> l;
    { std::lock_guard<std::mutex> guard(g_lock); auto it=g_session_listeners.find(handle); if(it==g_session_listeners.end()) return 0; l=it->second; g_session_listeners.erase(it); }
    l->close();
    return 0;
}

// Open an interactive context to a named service on the route of peer.
// dev32: protection "" or "auto" = the service's profile; otherwise none, authenticate or encrypt as a minimum.
// dev35: keyPrincipal opens with the keys held for that principal (a client's
// keys, gateway mode B); omitted or "" uses the service's own keys.
RexxRoutine5(uint64_t, xtpNativeSessionOpen,
             CSTRING, peer,
             CSTRING, service,
             OPTIONAL_int, openTimeoutMs,
             OPTIONAL_CSTRING, protection,
             OPTIONAL_CSTRING, keyPrincipal)
{
    try {
        xtp::SessionOptions o; o.service_name=service?service:"";
        if(keyPrincipal) o.key_principal=keyPrincipal;
        if(argumentExists(3)) o.open_timeout_ms=openTimeoutMs;
        if(protection&&*protection&&std::string(protection)!="auto") o.protection=xtp::parse_protection(protection);
        return keep_session(xtp::open_session(route_for_peer(peer),o));
    } catch (const std::exception &e) { raise_error(context, std::string("XTP session open: ")+e.what()); return 0; }
}

// Queue data; eom = 1 ends a message.  Returns the number of bytes queued.
RexxRoutine4(size_t, xtpNativeSessionWrite,
             uint64_t, handle,
             RexxStringObject, data,
             OPTIONAL_int, eom,
             OPTIONAL_int, timeoutMs)
{
    try {
        auto s=session_for(handle);
        const char *p=context->StringData(data); const size_t n=context->StringLength(data);
        s->write(std::vector<uint8_t>(p,p+n),argumentExists(3)&&eom!=0,argumentExists(4)?timeoutMs:-1);
        return n;
    } catch (const std::exception &e) { raise_error(context, std::string("XTP session write: ")+e.what()); return 0; }
}

// Returns an array: [1] the bytes read, [2] "EOM" if they end a message,
// "END" if the peer has closed its direction (no bytes), "TIMEOUT" if nothing
// arrived within timeoutMs, otherwise "".
RexxRoutine3(RexxObjectPtr, xtpNativeSessionRead,
             uint64_t, handle,
             size_t, maxBytes,
             OPTIONAL_int, timeoutMs)
{
    try {
        auto s=session_for(handle);
        auto c=s->read(maxBytes,argumentExists(3)?timeoutMs:-1);
        const char *flag=c.end?"END":c.eom?"EOM":c.data.empty()?"TIMEOUT":"";
        RexxArrayObject out=context->NewArray(2);
        context->ArrayPut(out,context->NewString(reinterpret_cast<const char*>(c.data.data()),c.data.size()),1);
        context->ArrayPut(out,context->NewStringFromAsciiz(flag),2);
        return out;
    } catch (const std::exception &e) { raise_error(context, std::string("XTP session read: ")+e.what()); return NULLOBJECT; }
}

RexxRoutine1(int, xtpNativeSessionShutdown,
             uint64_t, handle)
{
    try { session_for(handle)->shutdown_write(); return 0; }
    catch (const std::exception &e) { raise_error(context, std::string("XTP session shutdown: ")+e.what()); return -1; }
}

// Graceful close; releases the handle.  Returns 1 if both directions closed.
RexxRoutine2(int, xtpNativeSessionClose,
             uint64_t, handle,
             OPTIONAL_int, timeoutMs)
{
    std::shared_ptr<xtp::Session> s;
    { std::lock_guard<std::mutex> guard(g_lock); auto it=g_sessions.find(handle); if(it==g_sessions.end()) return 0; s=it->second; g_sessions.erase(it); }
    try { return s->close(argumentExists(2)?timeoutMs:5000)?1:0; }
    catch (const std::exception &e) { raise_error(context, std::string("XTP session close: ")+e.what()); return -1; }
}

// Abort; releases the handle.
RexxRoutine1(int, xtpNativeSessionAbort,
             uint64_t, handle)
{
    std::shared_ptr<xtp::Session> s;
    { std::lock_guard<std::mutex> guard(g_lock); auto it=g_sessions.find(handle); if(it==g_sessions.end()) return 0; s=it->second; g_sessions.erase(it); }
    s->abort();
    return 0;
}

// "key=K service=S peer=P open=0|1 peerClosed=0|1 srttMs=N retransmitted=N written=N read=N error=..."
RexxRoutine1(RexxStringObject, xtpNativeSessionInfo,
             uint64_t, handle)
{
    try {
        auto s=session_for(handle); auto st=s->stats();
        std::string i="key="+std::to_string(s->key())+" service="+s->service_name()+" peer="+s->peer_address()+
            " open="+(s->is_open()?"1":"0")+" peerClosed="+(s->peer_closed()?"1":"0")+
            " srttMs="+std::to_string(int(st.srtt_ms))+" retransmitted="+std::to_string(st.retransmitted_packets)+
            " protection="+xtp::protection_name(s->protection())+" keyId="+(s->key_id()?key_hex(s->key_id()):std::string("-"))+" authFailures="+std::to_string(st.auth_failures)+" replaysRejected="+std::to_string(st.replays_rejected)+" written="+std::to_string(st.bytes_written)+" read="+std::to_string(st.bytes_read)+" error="+s->error();
        return context->NewStringFromAsciiz(i.c_str());
    } catch (const std::exception &e) { raise_error(context, std::string("XTP session info: ")+e.what()); return context->NullString(); }
}

// ---------------------------------------------------------------------------
// dev32: per-service keys for ooRexx (decision D-07).  rexx/XtpServiceKeys.cls
// fetches keys from LDAP first and a key file second, and installs them here.
// Secrets cross as 64 hex digits and never come back out.
// ---------------------------------------------------------------------------
namespace {
uint64_t hex_u64(const char*h){
    std::string s(h?h:"");if(s.size()!=16)throw std::runtime_error("key id must be 16 hex digits");
    uint64_t v=0;for(char c:s){v<<=4;if(c>='0'&&c<='9')v|=uint64_t(c-'0');else if(c>='a'&&c<='f')v|=uint64_t(c-'a'+10);else if(c>='A'&&c<='F')v|=uint64_t(c-'A'+10);else throw std::runtime_error("key id is not hex");}
    return v;
}
std::string u64_hex(uint64_t v){char b[17];std::snprintf(b,sizeof b,"%016llx",(unsigned long long)v);return b;}
}

namespace {
void wipe_string(std::string&s){if(!s.empty())OPENSSL_cleanse(&s[0],s.size());}
bool one_word(const char*w){if(!w||!*w)return false;for(const char*p=w;*p;++p)if(*p==' '||*p=='\t'||*p=='\n'||*p=='\r')return false;return true;}
}

// One key, checked by the same strict parser as the key file (review L2).
RexxRoutine10(int, xtpNativeKeyInstall,
              CSTRING, service, CSTRING, keyIdHex, CSTRING, protection, CSTRING, suite, CSTRING, secretHex,
              OPTIONAL_CSTRING, principal, OPTIONAL_int64_t, notBeforeMs, OPTIONAL_int64_t, notAfterMs,
              OPTIONAL_int, active, OPTIONAL_CSTRING, source)
{
    std::string line;
    try {
        for(const char*w:{service,keyIdHex,protection,suite,secretHex})if(!one_word(w))throw std::runtime_error("service, key id, protection, suite and secret must each be one word");
        if(principal&&*principal&&!one_word(principal))throw std::runtime_error("principal must be one word");
        if((argumentExists(7)&&notBeforeMs<0)||(argumentExists(8)&&notAfterMs<0))throw std::runtime_error("not_before and not_after must not be negative");
        line=std::string(service)+" "+keyIdHex+" "+protection+" "+suite+" "+secretHex+" "+((principal&&*principal)?principal:"-")+" "+
             std::to_string(argumentExists(7)?notBeforeMs:0)+" "+std::to_string(argumentExists(8)?notAfterMs:0)+" "+((argumentExists(9)&&active==0)?"retiring":"active");
        // dev36 (review 1): a key installed by a program call is always "api";
        // "ldap" and "file" belong to the key sources (XtpServiceKeys.cls)
        if(source&&*source&&std::string(source)!="api")throw std::runtime_error("a key installed by a call has source api; ldap and file keys come through their key sources");
        xtp::ServiceKey k=xtp::parse_key_line(line,"api");
        wipe_string(line);
        xtp::KeyTable::global().install(k);
        return 0;
    } catch (const std::exception &e) {
        wipe_string(line);
        raise_error(context, std::string("XTP key install: ")+e.what()); return -1;
    }
}

// Replace every key of source with keys, one per line in the key-file format,
// in one step (review H2).  On any error nothing changes and a syntax error is raised.
RexxRoutine2(size_t, xtpNativeKeyReplaceSource, CSTRING, source, RexxStringObject, lines)
{
    std::string text(context->StringData(lines),context->StringLength(lines));
    // dev36: the key source names are a fixed vocabulary, so evidence can name them
    { const std::string src=source?source:""; if(src!="ldap"&&src!="file"&&src!="api"){wipe_string(text);raise_error(context,"XTP key replace: source must be ldap, file or api");return 0;} }
    try { const size_t n=xtp::KeyTable::global().replace_source_text(source?source:"",text); wipe_string(text); return n; }
    catch (const std::exception &e) { wipe_string(text); raise_error(context, std::string("XTP key replace (")+(source?source:"")+"): "+e.what()); return 0; }
}

// Raise a service's profile ahead of its keys; lower it back to its keys (operator only).
RexxRoutine2(int, xtpNativeServiceRequire, CSTRING, service, CSTRING, protection)
{
    try { xtp::KeyTable::global().require(service?service:"",xtp::parse_protection(protection?protection:"")); return 0; }
    catch (const std::exception &e) { raise_error(context, std::string("XTP service require: ")+e.what()); return -1; }
}
RexxRoutine1(int, xtpNativeServiceForgetProfile, CSTRING, service)
{
    xtp::KeyTable::global().forget_profile(service?service:""); return 0;
}

RexxRoutine1(size_t, xtpNativeKeyClearSource, CSTRING, source)
{
    return xtp::KeyTable::global().clear_source(source?source:"");
}

RexxRoutine1(size_t, xtpNativeKeyLoadFile, CSTRING, path)
{
    try { return xtp::KeyTable::global().load_file(path?path:""); }
    catch (const std::exception &e) { raise_error(context, std::string("XTP key file: ")+e.what()); return 0; }
}

RexxRoutine1(int, xtpNativeKeyRevoke, CSTRING, keyIdHex)
{
    try { return xtp::KeyTable::global().revoke(hex_u64(keyIdHex))?1:0; }
    catch (const std::exception &e) { raise_error(context, std::string("XTP key revoke: ")+e.what()); return -1; }
}

RexxRoutine1(RexxStringObject, xtpNativeServiceProtection, CSTRING, service)
{
    return context->NewStringFromAsciiz(xtp::protection_name(xtp::KeyTable::global().required(service?service:"")));
}

// One line per key, no secrets: service keyIdHex protection suite principal|- source active|retiring notBeforeMs notAfterMs
RexxRoutine0(RexxStringObject, xtpNativeKeyList)
{
    std::string out;
    for(const auto&k:xtp::KeyTable::global().list()){
        out+=k.service+" "+u64_hex(k.key_id)+" "+xtp::protection_name(k.protection)+" "+xtp::suite_name(k.suite)+" "+(k.principal.empty()?"-":k.principal)+" "+k.source+" "+(k.active?"active":"retiring")+" "+std::to_string(k.not_before_ms)+" "+std::to_string(k.not_after_ms)+"\n";
    }
    return context->NewString(out.data(),out.size());
}

// ---------------------------------------------------------------------------
// dev36: protection evidence (REQ-00001733).  What libxtp itself knows about a
// named service's protection, for a caller that must admit a route (API Client,
// Wire runtime) without trusting its own request options.  No secrets.
// Each value is one word, given exactly: a reader splits each word at its
// first '=' (service names and principals may contain '=', never a blank).
// ---------------------------------------------------------------------------
namespace {
std::string word(const std::string&v){
    if(v.empty())return "-";
    for(unsigned char c:v)if(c<=0x20||c==0x7f)throw std::runtime_error("a value for the evidence contains a blank or control character");
    return v;
}
// The key's fields and state now, from one snapshot of the table.  serial
// (non-zero) is the serial the caller holds: a different one means the secret
// under this id was replaced.  State: active, retiring, notyet, expired,
// absent (revoked or never there), replaced.
struct KeyView{std::string fields,state;};
KeyView key_view(uint64_t id,const std::string&service,uint64_t serial){
    if(!id)return {"keySuite=- keySource=- keyState=- keyNotBeforeMs=- keyNotAfterMs=-","-"};
    const int64_t now=xtp::security::now_ms();
    for(const auto&k:xtp::KeyTable::global().list()){
        if(k.key_id!=id)continue;
        std::string state;
        if(k.service!=service)state="absent";
        else if(serial&&k.serial!=serial)state="replaced";
        else if(k.not_before_ms&&now<k.not_before_ms)state="notyet";
        else if(k.not_after_ms&&now>=k.not_after_ms)state="expired";
        else state=k.active?"active":"retiring";
        if(state=="absent"||state=="replaced")return {"keySuite=- keySource=- keyState="+state+" keyNotBeforeMs=- keyNotAfterMs=-",state};
        return {"keySuite="+std::string(xtp::suite_name(k.suite))+" keySource="+word(k.source)+" keyState="+state+
                " keyNotBeforeMs="+std::to_string(k.not_before_ms)+" keyNotAfterMs="+std::to_string(k.not_after_ms),state};
    }
    return {"keySuite=- keySource=- keyState=absent keyNotBeforeMs=- keyNotAfterMs=-","absent"};
}
int rank_of(xtp::Protection p){return p==xtp::Protection::Encrypt?2:p==xtp::Protection::Authenticate?1:0;}
}

// Bound to an open session: what was agreed when the session opened, and the
// key's state now.  A protected session exists only after key confirmation, so
// its peer has proved it holds the secret of keyId.
// "service= peer= open= protection= suite= keyId= keyPrincipal= profile= keySuite= keySource= keyState= keyNotBeforeMs= keyNotAfterMs= atMs="
RexxRoutine1(RexxStringObject, xtpNativeSessionEvidence, uint64_t, handle)
{
    try {
        auto s=session_for(handle);
        const std::string svc=s->service_name();const auto prot=s->protection();const uint64_t id=s->key_id();
        std::string e="service="+word(svc)+" peer="+word(s->peer_address())+" open="+(s->is_open()?"1":"0")+
            " protection="+xtp::protection_name(prot)+" suite="+(prot==xtp::Protection::None?std::string("-"):std::string(xtp::suite_name(s->suite())))+
            " keyId="+(id?key_hex(id):std::string("-"))+" keyPrincipal="+word(s->key_principal())+
            " profile="+xtp::protection_name(xtp::KeyTable::global().required(svc))+" "+key_view(id,svc,s->key_serial()).fields+
            " atMs="+std::to_string(xtp::security::now_ms());
        return context->NewStringFromAsciiz(e.c_str());
    } catch (const std::exception &e) { raise_error(context, std::string("XTP session evidence: ")+e.what()); return context->NullString(); }
}

// Not yet opened: what an open of service on the route of peer would get now,
// from the route table and the key table, making the choices open_session
// makes.  minimum is a caller's floor (none|authenticate|encrypt|auto); it can
// raise the expected protection, never lower it below the profile.  The open
// resolves the route and chooses the key again, so only session evidence binds.
// "route= layer= carrier= destination= service= profile= protection= openable=1|0 reason= keyId= keyPrincipal= keySuite= keySource= keyState= keyNotBeforeMs= keyNotAfterMs= atMs="
RexxRoutine4(RexxStringObject, xtpNativeServiceEvidence, CSTRING, peer, CSTRING, service, OPTIONAL_CSTRING, principal, OPTIONAL_CSTRING, minimum)
{
    try {
        const std::string svc=service?service:"";const std::string who=(principal&&*principal)?principal:"";
        if(!xtp::valid_service_name(svc))throw std::runtime_error("invalid XTP named service: "+svc);
        std::string routeFields;bool routed=true;
        { xtp::SocketProvider provider; auto sel=provider.select(peer?peer:"");
          if(sel)routeFields="route="+word(peer?peer:"")+" layer="+std::to_string(sel->route.layer)+" carrier="+word(sel->route.carrier)+" destination="+word(sel->route.destination);
          else{routed=false;routeFields="route="+word(peer?peer:"")+" layer=- carrier=- destination=-";} }
        const auto profile=xtp::KeyTable::global().required(svc);
        auto want=profile;
        if(minimum&&*minimum&&std::string(minimum)!="auto"){auto m=xtp::parse_protection(minimum);if(rank_of(m)>rank_of(want))want=m;}
        uint64_t id=0,serial=0;std::string reason="-",holder;bool openable=true;
        if(!routed){openable=false;reason="no_route";}   // open_session resolves the route first
        if(want!=xtp::Protection::None){
            // the same choice open_session makes: the newest active key held
            // for exactly this principal; a stronger key raises the protection
            auto k=xtp::KeyTable::global().for_open(svc,who);
            if(!k){if(openable){openable=false;reason=who.empty()?"no_active_key":"no_active_key_for_principal";}}
            else{id=k->key_id;serial=k->serial;holder=k->principal;if(rank_of(k->protection)>rank_of(want))want=k->protection;}
        }
        const KeyView v=key_view(id,svc,serial);
        // review 9: the key changed between choosing it and reading it
        if(id&&v.state!="active"&&openable){openable=false;reason="key_changed";}
        std::string e=routeFields+" service="+word(svc)+" profile="+xtp::protection_name(profile)+" protection="+xtp::protection_name(want)+
            " openable="+(openable?"1":"0")+" reason="+reason+" keyId="+(id?key_hex(id):std::string("-"))+" keyPrincipal="+word(holder)+
            " "+v.fields+" atMs="+std::to_string(xtp::security::now_ms());
        return context->NewStringFromAsciiz(e.c_str());
    } catch (const std::exception &e) { raise_error(context, std::string("XTP service evidence: ")+e.what()); return context->NullString(); }
}

RexxRoutineEntry xtp_native_routines[] = {
    REXX_TYPED_ROUTINE(xtpNativeListenerOpen, xtpNativeListenerOpen),
    REXX_TYPED_ROUTINE(xtpNativeListenerOpenRoute, xtpNativeListenerOpenRoute),
    REXX_TYPED_ROUTINE(xtpNativeListenerReceive, xtpNativeListenerReceive),
    REXX_TYPED_ROUTINE(xtpNativeListenerClose, xtpNativeListenerClose),
    REXX_TYPED_ROUTINE(xtpNativeSend, xtpNativeSend),
    REXX_TYPED_ROUTINE(xtpNativeSendService, xtpNativeSendService),
    REXX_TYPED_ROUTINE(xtpNativeSendServicePriority, xtpNativeSendServicePriority),
    REXX_TYPED_ROUTINE(xtpNativeSendServicePriorityRate, xtpNativeSendServicePriorityRate),
    REXX_TYPED_ROUTINE(xtpNativeListenerOpenServices, xtpNativeListenerOpenServices),
    REXX_TYPED_ROUTINE(xtpNativeListenerLastService, xtpNativeListenerLastService),
    REXX_TYPED_ROUTINE(xtpNativeListenerLastProtection, xtpNativeListenerLastProtection),
    REXX_TYPED_ROUTINE(xtpNativeSendRoute, xtpNativeSendRoute),
    REXX_TYPED_ROUTINE(xtpNativeSendPriority, xtpNativeSendPriority),
    REXX_TYPED_ROUTINE(xtpNativeMulticastListenerOpen, xtpNativeMulticastListenerOpen),
    REXX_TYPED_ROUTINE(xtpNativeMulticastListenerOpenEx, xtpNativeMulticastListenerOpenEx),
    REXX_TYPED_ROUTINE(xtpNativeMulticastListenerOpenRate, xtpNativeMulticastListenerOpenRate),
    REXX_TYPED_ROUTINE(xtpNativeMulticastListenerReceive, xtpNativeMulticastListenerReceive),
    REXX_TYPED_ROUTINE(xtpNativeMulticastListenerClose, xtpNativeMulticastListenerClose),
    REXX_TYPED_ROUTINE(xtpNativeMulticastSend, xtpNativeMulticastSend),
    REXX_TYPED_ROUTINE(xtpNativeMulticastSendEx, xtpNativeMulticastSendEx),
    REXX_TYPED_ROUTINE(xtpNativeMulticastSendRate, xtpNativeMulticastSendRate),
    REXX_TYPED_ROUTINE(xtpNativeMulticastSendPriority, xtpNativeMulticastSendPriority),
    REXX_TYPED_ROUTINE(xtpNativeMultipathListenerOpen, xtpNativeMultipathListenerOpen),
    REXX_TYPED_ROUTINE(xtpNativeMultipathListenerReceive, xtpNativeMultipathListenerReceive),
    REXX_TYPED_ROUTINE(xtpNativeMultipathListenerClose, xtpNativeMultipathListenerClose),
    REXX_TYPED_ROUTINE(xtpNativeMultipathLastProtection, xtpNativeMultipathLastProtection),
    REXX_TYPED_ROUTINE(xtpNativeMultipathSend, xtpNativeMultipathSend),
    REXX_TYPED_ROUTINE(xtpNativeSessionListen, xtpNativeSessionListen),
    REXX_TYPED_ROUTINE(xtpNativeSessionAccept, xtpNativeSessionAccept),
    REXX_TYPED_ROUTINE(xtpNativeSessionListenerClose, xtpNativeSessionListenerClose),
    REXX_TYPED_ROUTINE(xtpNativeSessionOpen, xtpNativeSessionOpen),
    REXX_TYPED_ROUTINE(xtpNativeSessionWrite, xtpNativeSessionWrite),
    REXX_TYPED_ROUTINE(xtpNativeSessionRead, xtpNativeSessionRead),
    REXX_TYPED_ROUTINE(xtpNativeSessionShutdown, xtpNativeSessionShutdown),
    REXX_TYPED_ROUTINE(xtpNativeSessionClose, xtpNativeSessionClose),
    REXX_TYPED_ROUTINE(xtpNativeSessionAbort, xtpNativeSessionAbort),
    REXX_TYPED_ROUTINE(xtpNativeSessionInfo, xtpNativeSessionInfo),
    REXX_TYPED_ROUTINE(xtpNativeKeyInstall, xtpNativeKeyInstall),
    REXX_TYPED_ROUTINE(xtpNativeKeyClearSource, xtpNativeKeyClearSource),
    REXX_TYPED_ROUTINE(xtpNativeKeyLoadFile, xtpNativeKeyLoadFile),
    REXX_TYPED_ROUTINE(xtpNativeKeyRevoke, xtpNativeKeyRevoke),
    REXX_TYPED_ROUTINE(xtpNativeServiceProtection, xtpNativeServiceProtection),
    REXX_TYPED_ROUTINE(xtpNativeKeyList, xtpNativeKeyList),
    REXX_TYPED_ROUTINE(xtpNativeKeyReplaceSource, xtpNativeKeyReplaceSource),
    REXX_TYPED_ROUTINE(xtpNativeServiceRequire, xtpNativeServiceRequire),
    REXX_TYPED_ROUTINE(xtpNativeServiceForgetProfile, xtpNativeServiceForgetProfile),
    REXX_TYPED_ROUTINE(xtpNativeSessionEvidence, xtpNativeSessionEvidence),
    REXX_TYPED_ROUTINE(xtpNativeServiceEvidence, xtpNativeServiceEvidence),
    REXX_LAST_ROUTINE()
};

RexxPackageEntry oorexx_xtp_native_package_entry = {
    STANDARD_PACKAGE_HEADER
    REXX_INTERPRETER_5_0_0,
    "oorexx_xtp_native",
    "0.1-dev36",
    nullptr,
    nullptr,
    xtp_native_routines,
    nullptr
};

OOREXX_GET_PACKAGE(oorexx_xtp_native);

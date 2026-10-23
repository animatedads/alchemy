#pragma once
#include <atomic>
#include <condition_variable>
#include <cstddef>
#include <deque>
#include <map>
#include <memory>
#include <mutex>
#include <string>
#include <thread>

namespace grpcstream {
struct Options {
    std::string base, path, request, caFile;
    long timeoutMs=10000;
    std::map<std::string,std::string> metadata;
};
struct Event {
    std::string kind="IDLE", chunk, message, grpcStatus, grpcMessage;
    int code=0;
    long httpStatus=0, httpVersion=0;
};
class Session : public std::enable_shared_from_this<Session> {
public:
    explicit Session(Options options);
    ~Session();
    Session(const Session&)=delete;
    Session& operator=(const Session&)=delete;
    void start();
    Event poll(int waitMs);
    void cancel();
    void close();
private:
    Options options_;
    std::mutex mutex_;
    std::condition_variable cv_;
    std::deque<std::string> chunks_;
    std::size_t buffered_=0, total_=0;
    std::atomic<bool> cancelled_{false};
    bool ended_=false, overflow_=false;
    Event final_;
    std::thread worker_;
    struct ResponseHeaders {
        std::string type, status, message;
        bool sawStatus=false, duplicate=false, statusInHeaders=false, headEnded=false;
    } headers_;
    void run();
    static std::size_t receive(char*,std::size_t,std::size_t,void*);
    static std::size_t header(char*,std::size_t,std::size_t,void*);
    static int progress(void*,long long,long long,long long,long long);
    void finish(Event result);
};
Event validate(const Options &options);
} // namespace grpcstream

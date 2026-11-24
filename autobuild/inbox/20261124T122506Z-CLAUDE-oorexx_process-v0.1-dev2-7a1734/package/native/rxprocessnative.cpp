#include <oorexxapi.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <sys/poll.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <signal.h>
#include <unistd.h>
#include <errno.h>
#include <string.h>
#include <stdint.h>
#include <stdlib.h>
#include <chrono>
#include <string>
#include <vector>
#include <sys/syscall.h>
#ifndef CLOSE_RANGE_CLOEXEC
#define CLOSE_RANGE_CLOEXEC (1U << 2)
#endif

/* dev2 (Claude (Opus 5.5), 24 November 2026; architecture Tom Dyer):
 * descriptor stdio, detached start with a later reap, and close-on-exec for
 * every descriptor above 2 in the child, so a parent's sockets never leak
 * into a program it starts. */
static void markCloexecFrom3()
{
    if (syscall(SYS_close_range, 3U, ~0U, CLOSE_RANGE_CLOEXEC) == 0) return;
    for (int fd = 3; fd < 65536; ++fd)
    {
        int f = fcntl(fd, F_GETFD);
        if (f >= 0) fcntl(fd, F_SETFD, f | FD_CLOEXEC);
    }
}

static bool validFd(int64_t fd)
{
    return fd >= 0 && fd < 1048576 && fcntl((int)fd, F_GETFD) >= 0;
}

static RexxDirectoryObject resultDir(RexxCallContext *c, bool ok)
{
    RexxDirectoryObject d = c->NewDirectory();
    c->DirectoryPut(d, ok ? c->True() : c->False(), "OK");
    c->DirectoryPut(d, c->NewStringFromAsciiz("rxprocessnative"), "PROVIDER");
    return d;
}

static void putString(RexxCallContext *c, RexxDirectoryObject d, const char *key, const std::string &s)
{
    c->DirectoryPut(d, c->NewString(s.data(), s.size()), key);
}
static void putCString(RexxCallContext *c, RexxDirectoryObject d, const char *key, const char *s)
{
    c->DirectoryPut(d, c->NewStringFromAsciiz(s ? s : ""), key);
}
static void putI64(RexxCallContext *c, RexxDirectoryObject d, const char *key, int64_t v)
{
    c->DirectoryPut(d, c->Int64ToObject(v), key);
}
static void putBool(RexxCallContext *c, RexxDirectoryObject d, const char *key, bool v)
{
    c->DirectoryPut(d, v ? c->True() : c->False(), key);
}

static RexxObjectPtr errorResult(RexxCallContext *c, int err, const char *stage)
{
    RexxDirectoryObject d = resultDir(c, false);
    putI64(c, d, "ERRNO", err);
    putCString(c, d, "ERROR_MESSAGE", strerror(err));
    putCString(c, d, "STAGE", stage);
    return d;
}

static RexxObjectPtr opt(RexxCallContext *c, RexxDirectoryObject d, const char *name)
{
    RexxObjectPtr o = c->DirectoryAt(d, name);
    return o == NULLOBJECT ? c->Nil() : o;
}

static std::string optString(RexxCallContext *c, RexxDirectoryObject d, const char *name, const char *def)
{
    RexxObjectPtr o = opt(c, d, name);
    if (o == c->Nil()) return std::string(def ? def : "");
    RexxStringObject s = c->ObjectToString(o);
    return std::string(c->StringData(s), c->StringLength(s));
}

static int64_t optI64(RexxCallContext *c, RexxDirectoryObject d, const char *name, int64_t def)
{
    RexxObjectPtr o = opt(c, d, name);
    if (o == c->Nil()) return def;
    int64_t v = def;
    if (!c->ObjectToInt64(o, &v)) return def;
    return v;
}

static bool optBool(RexxCallContext *c, RexxDirectoryObject d, const char *name, bool def)
{
    RexxObjectPtr o = opt(c, d, name);
    if (o == c->Nil()) return def;
    logical_t v = def ? 1 : 0;
    if (!c->ObjectToLogical(o, &v)) return def;
    return v != 0;
}

static void closeIf(int &fd)
{
    if (fd >= 0) { close(fd); fd = -1; }
}

static int setNonblock(int fd)
{
    int flags = fcntl(fd, F_GETFL, 0);
    if (flags < 0) return -1;
    return fcntl(fd, F_SETFL, flags | O_NONBLOCK);
}

static int openNull(int flags) { return open("/dev/null", flags | O_CLOEXEC); }

RexxRoutine2(RexxObjectPtr, ProcessNativeRun, RexxArrayObject, argvObj, RexxObjectPtr, optionsObj)
{
    if (!context->IsDirectory(optionsObj)) return errorResult(context, EINVAL, "OPTIONS_TYPE");
    RexxDirectoryObject options = (RexxDirectoryObject)optionsObj;
    size_t argc = context->ArrayItems(argvObj);
    if (argc == 0) return errorResult(context, EINVAL, "ARGV");

    std::vector<std::string> args;
    args.reserve(argc);
    for (size_t i = 1; i <= argc; ++i)
    {
        RexxObjectPtr o = context->ArrayAt(argvObj, i);
        if (o == NULLOBJECT || o == context->Nil()) return errorResult(context, EINVAL, "ARGV");
        RexxStringObject s = context->ObjectToString(o);
        args.emplace_back(context->StringData(s), context->StringLength(s));
        if (args.back().find('\0') != std::string::npos) return errorResult(context, EINVAL, "ARGV_NUL");
    }
    if (args[0].empty()) return errorResult(context, EINVAL, "ARGV0");

    std::vector<char *> argv;
    argv.reserve(args.size() + 1);
    for (auto &s : args) argv.push_back(const_cast<char *>(s.c_str()));
    argv.push_back(nullptr);

    std::string cwd = optString(context, options, "CWD", "");
    std::string outPolicy = optString(context, options, "STDOUT_POLICY", "CAPTURE");
    std::string errPolicy = optString(context, options, "STDERR_POLICY", "CAPTURE");
    int64_t timeoutMs = optI64(context, options, "TIMEOUT_MS", 0);
    int64_t maxOutput = optI64(context, options, "MAX_OUTPUT_BYTES", 1048576);
    bool processGroup = optBool(context, options, "PROCESS_GROUP", false);
    if (timeoutMs < 0 || maxOutput < 0) return errorResult(context, EINVAL, "OPTIONS");

    RexxObjectPtr stdinObj = opt(context, options, "STDIN_BYTES");
    std::string stdinBytes;
    bool haveStdin = stdinObj != context->Nil();
    if (haveStdin)
    {
        RexxStringObject s = context->ObjectToString(stdinObj);
        stdinBytes.assign(context->StringData(s), context->StringLength(s));
    }

    auto validPolicy = [](const std::string &p) { return p == "CAPTURE" || p == "INHERIT" || p == "DISCARD"; };
    if (!(validPolicy(outPolicy) || outPolicy == "DESCRIPTOR") || !validPolicy(errPolicy)) return errorResult(context, EINVAL, "POLICY");

    /* dev2: descriptor stdio and detached start */
    int64_t stdinFd = optI64(context, options, "STDIN_FD", -1);
    int64_t stdoutFd = optI64(context, options, "STDOUT_FD", -1);
    bool detach = optBool(context, options, "DETACH", false);
    if (stdinFd >= 0 && haveStdin) return errorResult(context, EINVAL, "STDIN_CONFLICT");
    if (stdinFd >= 0 && !validFd(stdinFd)) return errorResult(context, EBADF, "STDIN_FD");
    if (outPolicy == "DESCRIPTOR" && !validFd(stdoutFd)) return errorResult(context, EBADF, "STDOUT_FD");
    if (outPolicy != "DESCRIPTOR" && stdoutFd >= 0) return errorResult(context, EINVAL, "STDOUT_FD_POLICY");
    if (detach && (outPolicy == "CAPTURE" || errPolicy == "CAPTURE" || haveStdin || timeoutMs > 0))
        return errorResult(context, EINVAL, "DETACH_CONFLICT");

    int outPipe[2] = {-1,-1}, errPipe[2] = {-1,-1}, inPipe[2] = {-1,-1}, execPipe[2] = {-1,-1};
    if (outPolicy == "CAPTURE" && pipe2(outPipe, O_CLOEXEC) != 0) return errorResult(context, errno, "PIPE_STDOUT");
    if (errPolicy == "CAPTURE" && pipe2(errPipe, O_CLOEXEC) != 0) { int e=errno; closeIf(outPipe[0]); closeIf(outPipe[1]); return errorResult(context,e,"PIPE_STDERR"); }
    if (haveStdin && pipe2(inPipe, O_CLOEXEC) != 0) { int e=errno; closeIf(outPipe[0]); closeIf(outPipe[1]); closeIf(errPipe[0]); closeIf(errPipe[1]); return errorResult(context,e,"PIPE_STDIN"); }
    if (pipe2(execPipe, O_CLOEXEC) != 0) { int e=errno; closeIf(outPipe[0]); closeIf(outPipe[1]); closeIf(errPipe[0]); closeIf(errPipe[1]); closeIf(inPipe[0]); closeIf(inPipe[1]); return errorResult(context,e,"PIPE_EXEC"); }

    auto started = std::chrono::steady_clock::now();
    pid_t pid = fork();
    if (pid < 0)
    {
        int e = errno;
        closeIf(outPipe[0]); closeIf(outPipe[1]); closeIf(errPipe[0]); closeIf(errPipe[1]); closeIf(inPipe[0]); closeIf(inPipe[1]); closeIf(execPipe[0]); closeIf(execPipe[1]);
        return errorResult(context, e, "FORK");
    }

    if (pid == 0)
    {
        close(execPipe[0]);
        if (processGroup && setpgid(0, 0) != 0) { int e=errno; (void)!write(execPipe[1], &e, sizeof(e)); _exit(126); }
        { sigset_t none; sigemptyset(&none); sigprocmask(SIG_SETMASK, &none, NULL); signal(SIGPIPE, SIG_DFL); }
        if (stdinFd >= 0 && dup2((int)stdinFd, STDIN_FILENO) < 0) { int e=errno; (void)!write(execPipe[1], &e, sizeof(e)); _exit(126); }
        if (outPolicy == "DESCRIPTOR" && dup2((int)stdoutFd, STDOUT_FILENO) < 0) { int e=errno; (void)!write(execPipe[1], &e, sizeof(e)); _exit(126); }
        if (!cwd.empty() && chdir(cwd.c_str()) != 0) { int e=errno; (void)!write(execPipe[1], &e, sizeof(e)); _exit(126); }

        if (haveStdin)
        {
            close(inPipe[1]);
            if (dup2(inPipe[0], STDIN_FILENO) < 0) { int e=errno; (void)!write(execPipe[1], &e, sizeof(e)); _exit(126); }
        }
        if (outPolicy == "CAPTURE")
        {
            close(outPipe[0]);
            if (dup2(outPipe[1], STDOUT_FILENO) < 0) { int e=errno; (void)!write(execPipe[1], &e, sizeof(e)); _exit(126); }
        }
        else if (outPolicy == "DISCARD")
        {
            int n = openNull(O_WRONLY); if (n < 0 || dup2(n, STDOUT_FILENO) < 0) { int e=errno; (void)!write(execPipe[1], &e, sizeof(e)); _exit(126); } if (n > STDERR_FILENO) close(n);
        }
        if (errPolicy == "CAPTURE")
        {
            close(errPipe[0]);
            if (dup2(errPipe[1], STDERR_FILENO) < 0) { int e=errno; (void)!write(execPipe[1], &e, sizeof(e)); _exit(126); }
        }
        else if (errPolicy == "DISCARD")
        {
            int n = openNull(O_WRONLY); if (n < 0 || dup2(n, STDERR_FILENO) < 0) { int e=errno; (void)!write(execPipe[1], &e, sizeof(e)); _exit(126); } if (n > STDERR_FILENO) close(n);
        }

        closeIf(outPipe[0]); closeIf(outPipe[1]); closeIf(errPipe[0]); closeIf(errPipe[1]); closeIf(inPipe[0]); closeIf(inPipe[1]);
        markCloexecFrom3();
        execvp(argv[0], argv.data());
        int e = errno;
        (void)!write(execPipe[1], &e, sizeof(e));
        _exit(127);
    }

    close(execPipe[1]);

    if (detach)
    {
        /* The exec pipe closes on a successful exec (CLOEXEC); an errno arrives otherwise. */
        int e = 0; ssize_t n;
        do n = read(execPipe[0], &e, sizeof(e)); while (n < 0 && errno == EINTR);
        closeIf(execPipe[0]);
        if (n == (ssize_t)sizeof(e))
        {
            int st = 0; while (waitpid(pid, &st, 0) < 0 && errno == EINTR) {}
            return errorResult(context, e, "EXEC");
        }
        RexxDirectoryObject d = resultDir(context, true);
        putI64(context, d, "PID", pid);
        putI64(context, d, "DURATION_MS", 0);
        putBool(context, d, "TIMED_OUT", false);
        putBool(context, d, "OUTPUT_TRUNCATED", false);
        putString(context, d, "STDOUT", "");
        putString(context, d, "STDERR", "");
        putI64(context, d, "EXIT_CODE", -1);
        putI64(context, d, "TERM_SIGNAL", 0);
        putCString(context, d, "TERMINATION", "RUNNING");
        return d;
    }
    if (outPolicy == "CAPTURE") { close(outPipe[1]); setNonblock(outPipe[0]); }
    if (errPolicy == "CAPTURE") { close(errPipe[1]); setNonblock(errPipe[0]); }
    if (haveStdin) { close(inPipe[0]); setNonblock(inPipe[1]); }
    setNonblock(execPipe[0]);

    std::string stdoutData, stderrData;
    size_t captured = 0;
    bool truncated = false, timedOut = false, reaped = false;
    int status = 0, execErr = 0;
    size_t stdinPos = 0;
    bool outOpen = outPolicy == "CAPTURE", errOpen = errPolicy == "CAPTURE", inOpen = haveStdin, execOpen = true;

    auto appendBounded = [&](std::string &target, const char *buf, size_t n)
    {
        size_t room = captured < (size_t)maxOutput ? (size_t)maxOutput - captured : 0;
        size_t take = n < room ? n : room;
        if (take) { target.append(buf, take); captured += take; }
        if (take < n) truncated = true;
    };

    while (!reaped || outOpen || errOpen || execOpen || inOpen)
    {
        if (!reaped)
        {
            pid_t w = waitpid(pid, &status, WNOHANG);
            if (w == pid) reaped = true;
            else if (w < 0 && errno != EINTR) { execErr = errno; reaped = true; }
        }

        auto now = std::chrono::steady_clock::now();
        int64_t elapsed = std::chrono::duration_cast<std::chrono::milliseconds>(now - started).count();
        if (!reaped && timeoutMs > 0 && elapsed >= timeoutMs)
        {
            timedOut = true;
            if (processGroup) kill(-pid, SIGTERM); else kill(pid, SIGTERM);
            usleep(100000);
            pid_t w = waitpid(pid, &status, WNOHANG);
            if (w != pid)
            {
                if (processGroup) kill(-pid, SIGKILL); else kill(pid, SIGKILL);
                while (waitpid(pid, &status, 0) < 0 && errno == EINTR) {}
            }
            reaped = true;
        }

        if (inOpen && stdinPos >= stdinBytes.size()) { closeIf(inPipe[1]); inOpen = false; }

        struct pollfd pfds[4]; int kinds[4]; nfds_t nfd = 0;
        if (outOpen) { pfds[nfd] = {outPipe[0], POLLIN|POLLHUP, 0}; kinds[nfd++] = 1; }
        if (errOpen) { pfds[nfd] = {errPipe[0], POLLIN|POLLHUP, 0}; kinds[nfd++] = 2; }
        if (execOpen) { pfds[nfd] = {execPipe[0], POLLIN|POLLHUP, 0}; kinds[nfd++] = 3; }
        if (inOpen) { pfds[nfd] = {inPipe[1], POLLOUT|POLLHUP, 0}; kinds[nfd++] = 4; }
        int prc = nfd ? poll(pfds, nfd, 20) : 0;
        if (prc < 0 && errno != EINTR) break;

        for (nfds_t i = 0; i < nfd; ++i)
        {
            if (!pfds[i].revents) continue;
            if (kinds[i] == 1 || kinds[i] == 2)
            {
                int fd = kinds[i] == 1 ? outPipe[0] : errPipe[0];
                for (;;)
                {
                    char buf[8192]; ssize_t n = read(fd, buf, sizeof(buf));
                    if (n > 0) appendBounded(kinds[i] == 1 ? stdoutData : stderrData, buf, (size_t)n);
                    else if (n == 0) { if (kinds[i] == 1) { closeIf(outPipe[0]); outOpen=false; } else { closeIf(errPipe[0]); errOpen=false; } break; }
                    else if (errno == EAGAIN || errno == EWOULDBLOCK) break;
                    else if (errno == EINTR) continue;
                    else { if (kinds[i] == 1) { closeIf(outPipe[0]); outOpen=false; } else { closeIf(errPipe[0]); errOpen=false; } break; }
                }
            }
            else if (kinds[i] == 3)
            {
                int e = 0; ssize_t n = read(execPipe[0], &e, sizeof(e));
                if (n == (ssize_t)sizeof(e)) execErr = e;
                if (n == 0 || n == (ssize_t)sizeof(e) || (n < 0 && errno != EAGAIN && errno != EWOULDBLOCK && errno != EINTR)) { closeIf(execPipe[0]); execOpen=false; }
            }
            else if (kinds[i] == 4)
            {
                ssize_t n = write(inPipe[1], stdinBytes.data()+stdinPos, stdinBytes.size()-stdinPos);
                if (n > 0) stdinPos += (size_t)n;
                else if (n < 0 && errno != EAGAIN && errno != EWOULDBLOCK && errno != EINTR) { closeIf(inPipe[1]); inOpen=false; }
            }
        }

        if (reaped && !outOpen && !errOpen && !execOpen) { closeIf(inPipe[1]); inOpen=false; }
    }

    closeIf(outPipe[0]); closeIf(errPipe[0]); closeIf(inPipe[1]); closeIf(execPipe[0]);

    if (execErr != 0) return errorResult(context, execErr, "EXEC");

    auto finished = std::chrono::steady_clock::now();
    int64_t durationMs = std::chrono::duration_cast<std::chrono::milliseconds>(finished - started).count();
    RexxDirectoryObject d = resultDir(context, true);
    putI64(context, d, "PID", pid);
    putI64(context, d, "DURATION_MS", durationMs);
    putBool(context, d, "TIMED_OUT", timedOut);
    putBool(context, d, "OUTPUT_TRUNCATED", truncated);
    putString(context, d, "STDOUT", stdoutData);
    putString(context, d, "STDERR", stderrData);
    putBool(context, d, "EXITED", WIFEXITED(status));
    putBool(context, d, "SIGNALED", WIFSIGNALED(status));
    putI64(context, d, "EXIT_CODE", WIFEXITED(status) ? WEXITSTATUS(status) : -1);
    putI64(context, d, "TERM_SIGNAL", WIFSIGNALED(status) ? WTERMSIG(status) : 0);
    putCString(context, d, "TERMINATION", timedOut ? "TIMEOUT" : (WIFSIGNALED(status) ? "SIGNAL" : "EXIT"));
    return d;
}

/* dev2: the state of a detached child, without blocking.  STATE is RUNNING,
 * EXIT, SIGNAL or GONE (not our child, or already reaped). */
RexxRoutine1(RexxObjectPtr, ProcessNativeReap, int64_t, pid)
{
    if (pid <= 0) return errorResult(context, EINVAL, "PID");
    int st = 0; pid_t w;
    do w = waitpid((pid_t)pid, &st, WNOHANG); while (w < 0 && errno == EINTR);
    RexxDirectoryObject d = resultDir(context, true);
    putI64(context, d, "PID", pid);
    if (w == 0) { putCString(context, d, "STATE", "RUNNING"); return d; }
    if (w < 0) { putCString(context, d, "STATE", "GONE"); putI64(context, d, "ERRNO", errno); return d; }
    putCString(context, d, "STATE", WIFSIGNALED(st) ? "SIGNAL" : "EXIT");
    putI64(context, d, "EXIT_CODE", WIFEXITED(st) ? WEXITSTATUS(st) : -1);
    putI64(context, d, "TERM_SIGNAL", WIFSIGNALED(st) ? WTERMSIG(st) : 0);
    return d;
}

/* dev2: send a signal to a child (group = 1: to its process group). */
RexxRoutine3(int, ProcessNativeSignal, int64_t, pid, int, sig, OPTIONAL_logical_t, group)
{
    if (pid <= 0) return EINVAL;
    pid_t target = (argumentExists(3) && group) ? -(pid_t)pid : (pid_t)pid;
    return kill(target, sig) == 0 ? 0 : errno;
}

RexxRoutineEntry process_routines[] = {
    REXX_TYPED_ROUTINE(ProcessNativeRun, ProcessNativeRun),
    REXX_TYPED_ROUTINE(ProcessNativeReap, ProcessNativeReap),
    REXX_TYPED_ROUTINE(ProcessNativeSignal, ProcessNativeSignal),
    REXX_LAST_ROUTINE()
};

RexxPackageEntry RxProcessNative_package_entry = {
    STANDARD_PACKAGE_HEADER
    REXX_INTERPRETER_4_0_0,
    "RxProcessNative",
    "0.1-dev2",
    NULL, NULL, process_routines, NULL
};
OOREXX_GET_PACKAGE(RxProcessNative);

// SLAM C++ reader fixture. Architecture: Tom Dyer. Code: Claude (Opus 5.5), 2026-10-28.
// run_tests.sh checks it with g++ -fsyntax-only, so every construct here is real C++.
#include <string>
#include <vector>
#define TWICE(x) \
    ((x) + \
     (x))

namespace demo {

static const char *kRaw = R"tag(a "raw" string; with { braces } and
two lines)tag";

class Rate {
public:
    explicit Rate(double mutationRate, double crossoverRate);
    int clamp(int limit) const;
private:
    double mutationRate;
    double crossoverRate;
    int limit{10};                       // a brace initializer: a field, not a block
};

// defined outside the class: owner Rate, and Rate's fields
Rate::Rate(double mutationRate, double crossoverRate) : mutationRate(0), crossoverRate(0) {
    if (mutationRate < 0 || mutationRate > 1) throw std::string("mutationRate");
    if (crossoverRate < 0 || crossoverRate > 1) {
        throw std::string("crossoverRate");
    }
    this->mutationRate = mutationRate;
    this->crossoverRate = crossoverRate;
}

int Rate::clamp(int limit) const {
    if (limit < 0) return 0;
    return limit;
}

template <class T>
T total(const std::vector<T> &values) {
    T sum = T();
    for (const auto &v : values) {
        if constexpr (sizeof(T) > 8) continue;
        sum += v;
    }
    return sum;
}

int pick(int code, const char *name) {
    if (name == nullptr) return -1;
    switch (code) {
        case 1: return TWICE(1);
        default: break;
    }
    int i = 0;
    do { i++; } while (i < 3);
    try {
        auto f = [&](int x) { return x + i; };
        return f(code);
    } catch (...) {
        return 0;
    }
}

} // namespace demo

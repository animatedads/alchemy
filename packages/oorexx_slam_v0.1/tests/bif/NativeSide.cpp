// Run each BIF case on the rx2cpp native pack (rxbif::invoke).
// Prints: ID ACCEPT hexvalue | ID REJECT | ID DEFER (the pack hands the case back to the interpreter)
// Architecture: Tom Dyer. Code: Claude (Opus 5.5), 2026-10-28.   Arg: cases file
#include "rxbif.hpp"
#include <fstream>
#include <iostream>
#include <sstream>
#include <iomanip>
#include <string>
#include <vector>
static std::string hex(const std::string &s) {
    std::ostringstream o;
    for (unsigned char c : s) o << std::uppercase << std::hex << std::setw(2) << std::setfill('0') << static_cast<int>(c);
    return o.str();
}
int main(int argc, char **argv) {
    if (argc < 2) return 2;
    std::ifstream in(argv[1]);
    std::string line;
    while (std::getline(in, line)) {
        std::vector<std::string> f;
        std::string cur;
        for (char c : line) { if (c == '|') { f.push_back(cur); cur.clear(); } else cur += c; }
        f.push_back(cur);
        if (f.size() < 6) continue;
        std::vector<rx::Value> args;
        const size_t n = std::stoul(f[5]);          // the count says how many, so one empty argument is not none
        for (size_t k = 0; k < n && 6 + k < f.size(); k++) args.push_back(rx::Value::string(f[6 + k]));
        rxbif::Context ctx;
        try {
            rx::Value v = rxbif::invoke(f[1], args, ctx);
            std::cout << f[0] << " ACCEPT " << hex(v.bytes) << "\n";
        } catch (const rxbif::NativeSubsetUnsupported &) {
            std::cout << f[0] << " DEFER\n";
        } catch (const std::exception &e) {
            std::cout << f[0] << " REJECT\n";
        }
    }
    return 0;
}

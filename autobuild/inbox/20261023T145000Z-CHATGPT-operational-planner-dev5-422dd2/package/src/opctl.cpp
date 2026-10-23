#include "operational/operational_planner.hpp"
#include <cstdlib>
#include <iostream>
#include <stdexcept>
using namespace operational;

static std::string policy_store() {
    const char *p = std::getenv("OPERATIONAL_POLICY_FILE");
    return p && *p ? p : "operational-classes.tsv";
}
static std::string capacity_store() {
    const char *p = std::getenv("OPERATIONAL_CAPACITY_FILE");
    return p && *p ? p : "operational-capacity.tsv";
}
static void usage() {
    std::cerr
        << "usage: opctl class add NAME --normal P --degraded P --constrained P --emergency P [--sort N] [--deadline-us N]\n"
        << "       policy P = disposition[:rate][:fallback][:protected][:per-context-cap][:max-parallel][:aggregate-cap]\n"
        << "       opctl class list\n"
        << "       opctl class show NAME\n"
        << "       opctl decide NAME STATE\n"
        << "       opctl capacity set DOMAIN NOMINAL_BPS [CURRENT_BPS]\n"
        << "       opctl capacity list\n"
        << "       opctl capacity show DOMAIN\n";
}

int main(int argc, char **argv) {
    try {
        if (argc < 3) { usage(); return 2; }
        const std::string a = argv[1], b = argv[2];

        if (a == "capacity") {
            auto cr = load_capacity_registry(capacity_store());
            if (b == "list") {
                for (const auto &d : cr.domains())
                    std::cout << d.name << ' ' << d.nominal_bytes_per_sec << ' ' << d.current_bytes_per_sec << '\n';
                return 0;
            }
            if (b == "show") {
                if (argc < 4) throw std::runtime_error("capacity domain required");
                const auto *d = cr.find(argv[3]);
                if (!d) return 3;
                std::cout << "DOMAIN=" << d->name
                          << " NOMINAL_BPS=" << d->nominal_bytes_per_sec
                          << " CURRENT_BPS=" << d->current_bytes_per_sec << '\n';
                return 0;
            }
            if (b == "set") {
                if (argc < 5) throw std::runtime_error("capacity set requires DOMAIN NOMINAL_BPS [CURRENT_BPS]");
                CapacityDomain d;
                d.name = argv[3];
                d.nominal_bytes_per_sec = std::stoull(argv[4]);
                d.current_bytes_per_sec = argc > 5 ? std::stoull(argv[5]) : d.nominal_bytes_per_sec;
                cr.set_domain(d);
                save_capacity_registry(cr, capacity_store());
                return 0;
            }
            usage(); return 2;
        }

        auto r = load_registry(policy_store());
        if (a == "class" && b == "list") {
            for (const auto &c : r.classes()) std::cout << c.name << '\n';
            return 0;
        }
        if (a == "class" && b == "show") {
            if (argc < 4) throw std::runtime_error("class name required");
            const auto *c = r.find(argv[3]);
            if (!c) return 3;
            std::cout << c->name;
            for (const auto &p : c->states) std::cout << ' ' << encode_state_policy(p);
            std::cout << '\n';
            return 0;
        }
        if (a == "class" && b == "add") {
            if (argc < 4) throw std::runtime_error("class name required");
            OperationalClass c; c.name = argv[3];
            for (auto &p : c.states) p = StatePolicy{};
            for (int i = 4; i < argc; ++i) {
                std::string k = argv[i];
                auto need = [&]() {
                    if (i + 1 >= argc) throw std::runtime_error("missing value for " + k);
                    return std::string(argv[++i]);
                };
                if (k == "--normal") c.states[0] = parse_state_policy(need());
                else if (k == "--degraded") c.states[1] = parse_state_policy(need());
                else if (k == "--constrained") c.states[2] = parse_state_policy(need());
                else if (k == "--emergency") c.states[3] = parse_state_policy(need());
                else if (k == "--sort") c.transport_sort = static_cast<uint32_t>(std::stoul(need()));
                else if (k == "--deadline-us") c.transport_deadline_us = std::stoull(need());
                else throw std::runtime_error("unknown argument: " + k);
            }
            r.register_class(c);
            save_registry(r, policy_store());
            return 0;
        }
        if (a == "decide") {
            if (argc < 4) throw std::runtime_error("class and state required");
            Planner p(r);
            auto d = p.decide(argv[2], parse_state(argv[3]));
            std::cout << "CLASS=" << d.class_name
                      << " STATE=" << state_name(d.state)
                      << " ACTION=" << disposition_name(d.policy.disposition)
                      << " RATE_PERCENT=" << unsigned(d.policy.rate_percent)
                      << " FALLBACK=" << fallback_name(d.policy.fallback)
                      << " PROTECTED_ONLY=" << (d.policy.protected_path_only ? 1 : 0)
                      << " PER_CONTEXT_CAP_PERCENT=" << unsigned(d.policy.per_context_cap_percent)
                      << " MAX_PARALLEL_CONTEXTS=" << d.policy.max_parallel_contexts
                      << " AGGREGATE_CAP_PERCENT=" << unsigned(d.policy.aggregate_cap_percent)
                      << " TRANSMIT=" << (d.permits_transmission() ? 1 : 0)
                      << " TRANSFORM=" << (d.requires_upstream_transform() ? 1 : 0);
            if (d.transport_sort) std::cout << " SORT=" << *d.transport_sort;
            if (d.transport_deadline_us) std::cout << " DEADLINE_US=" << *d.transport_deadline_us;
            std::cout << '\n';
            return 0;
        }
        usage(); return 2;
    } catch (const std::exception &e) {
        std::cerr << "opctl: " << e.what() << '\n';
        return 1;
    }
}

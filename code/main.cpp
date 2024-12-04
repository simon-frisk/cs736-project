#include <cstdint>
#include <csv.hpp>
#include <format>
#include <fstream>
#include <functional>
#include <gcache/ghost_kv_cache.h>
#include <iostream>
#include <memory>
#include <stdexcept>
#include <string>

#include "trace.hpp"

void saveMRCToFile(
    std::vector<std::tuple<uint32_t, uint32_t, gcache::CacheStat>> curve,
    std::string name) {
    std::ofstream file(std::format("mrc/{}.txt", name));

    for (auto& point : curve) {
        file << std::get<2>(point).get_hit_rate() << std::get<0>(point) << " "
             << std::get<1>(point) << std::get<2>(point) << std::endl;
    }

    file.close();
}

void initializeNewClientInGhost(
    int client,
    std::unordered_map<uint64_t, std::unique_ptr<gcache::SampledGhostKvCache<>>>&
        clientsGhostMap) {
    clientsGhostMap[client] = std::make_unique<gcache::SampledGhostKvCache<5>>(
        1024 * 64, 1024 * 64, 1024 * 1024);
}

void usage(std::string& execname) {
    std::cout << "usage: " << execname << " <tw|fb> <trace>" << std::endl;
    exit(1);
}

int main(int argc, char* argv[]) {
    std::string execname(argv[0]);
    if (argc != 3) {
        usage(execname);
    }

    // Choose parser to use for trace
    std::string which_trace(argv[1]);
    std::function<TraceReq(csv::CSVRow&)> parser;
    if (which_trace == "tw") {
        parser = TraceReq::fromTwitterLine;
    } else if (which_trace == "fb") {
        parser = TraceReq::fromFacebookLine;
    } else {
        usage(execname);
    }

    // Open trace and setup CSV parser
    std::ifstream file(argv[2]);
    csv::CSVReader reader(file);

    std::unordered_map<uint64_t, std::unique_ptr<gcache::SampledGhostKvCache<>>>
        clientsGhostMap;

    int row_number = 1;
    for (csv::CSVRow& row : reader) {
        try {
            auto req = parser(row);
            req.printTraceReq();

            if (clientsGhostMap.find(req.client) == clientsGhostMap.end()) {
                initializeNewClientInGhost(req.client, clientsGhostMap);
            }
            clientsGhostMap[req.client]->access(req.key,
                                                req.keySize + req.valSize);

        } catch (const std::runtime_error& e) {
            std::cerr << "Skipped line " << row_number
                      << " in trace (" << e.what()
                      << ")" << std::endl;
        }

        row_number++;
    }

    file.close();

    for (auto& kv : clientsGhostMap) {
        auto curve = kv.second->get_cache_stat_curve();
        if (curve.empty()) {
            std::cout << "client \"" << kv.first << "\" is empty" << std::endl;
            continue;
        }
        saveMRCToFile(curve, std::to_string(kv.first));
    }

    return 0;
}
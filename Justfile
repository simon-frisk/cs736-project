build:
    make -C build/

clean:
    make -C build/ clean

debug:
    cmake -S . -B build/ -DCMAKE_BUILD_TYPE=Debug -DCMAKE_CXX_FLAGS_DEBUG="-g -O0" --fresh

release:
    cmake -S . -B build/ -DCMAKE_BUILD_TYPE=Release --fresh
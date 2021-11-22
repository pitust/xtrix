set -ex

rm -rf build/user/$1 || true
mkdir -p build/user/$1 build/ucache
ldc2 --cache=build/ucache -mattr=-sse,-sse2,-sse3,-ssse3 -code-model=small -I src \
    -I phobos --relocation-model=static --gdwarf --oq \
    --od build/user/$1 `find src/$1 -type f | grep '\.d'` \
    -c --threads $(nproc) --betterC -mtriple=x86_64-linux-gnu --flto=full
ld.lld -r build/user/$1/*.o -o build/$1.o

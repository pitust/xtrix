module xtrm.util;

struct ArrayRepr(T) {
    ulong len;
    T* ptr;
    static ArrayRepr!(T) from(T[] arr) {
        return *cast(ArrayRepr!(T)*)(&arr);
    }
    static ArrayRepr!(T) from(T* data, ulong count) {
        return ArrayRepr!(T)(count, data);
    }
    T[] into() {
        return *cast(T[]*)(&this);
    }
}
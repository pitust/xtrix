wget https://raw.githubusercontent.com/ldc-developers/druntime/ldc-v$(ldc2 --version | head -n 1 | grep -Eo '[0-9\.]+')/src/object.d -O assets/object.d
cat >>assets/object.d <<EOF
private template Select(bool cond, T, U)
{
    static if (cond) alias Select = T;
    else alias Select = U;
}

private class TypeInfoArrayGeneric(T, Base = T) : Select!(is(T == Base), TypeInfo_Array, TypeInfoArrayGeneric!Base)
{
    static if (is(T == Base))
        override bool opEquals(Object o) { return TypeInfo.opEquals(o); }

    override string toString() const { return (T[]).stringof; }

    static if (is(T == Base))
        override size_t getHash(scope const void* p) @trusted const
        {
            return hashOf(*cast(const T[]*) p);
        }

    static if (is(T == Base))
        override bool equals(in void* p1, in void* p2) const
        {
            import core.stdc.string;
            auto s1 = *cast(T[]*)p1;
            auto s2 = *cast(T[]*)p2;
            return s1.length == s2.length &&
                memcmp(s1.ptr, s2.ptr, s1.length) == 0;
        }

    static if (is(T == Base) || (__traits(isIntegral, T) && T.max != Base.max))
        override int compare(in void* p1, in void* p2) const
        {
            auto s1 = *cast(T[]*)p1;
            auto s2 = *cast(T[]*)p2;
            auto len = s1.length;

            if (s2.length < len)
                len = s2.length;
            for (size_t u = 0; u < len; u++)
            {
                if (int result = (s1[u] > s2[u]) - (s1[u] < s2[u]))
                    return result;
            }
            return (s1.length > s2.length) - (s1.length < s2.length);
        }

    override @property inout(TypeInfo) next() inout
    {
        return cast(inout) typeid(T);
    }
}

// EXTRA
class TypeInfo_Ah : TypeInfoArrayGeneric!ubyte {}
class TypeInfo_Ab : TypeInfoArrayGeneric!(bool, ubyte) {}
class TypeInfo_Ag : TypeInfoArrayGeneric!(byte, ubyte) {}
class TypeInfo_Aa : TypeInfoArrayGeneric!(char, ubyte) {}
class TypeInfo_Axa : TypeInfoArrayGeneric!(const char) {}
class TypeInfo_Aya : TypeInfoArrayGeneric!(immutable char)
{
    // Must override this, otherwise "string" is returned.
    override string toString() const { return "immutable(char)[]"; }
}
class TypeInfo_At : TypeInfoArrayGeneric!ushort {}
class TypeInfo_As : TypeInfoArrayGeneric!(short, ushort) {}
class TypeInfo_Au : TypeInfoArrayGeneric!(wchar, ushort) {}
class TypeInfo_Ak : TypeInfoArrayGeneric!uint {}
class TypeInfo_Ai : TypeInfoArrayGeneric!(int, uint) {}
class TypeInfo_Aw : TypeInfoArrayGeneric!(dchar, uint) {}
class TypeInfo_Am : TypeInfoArrayGeneric!ulong {}
class TypeInfo_Al : TypeInfoArrayGeneric!(long, ulong) {}

EOF
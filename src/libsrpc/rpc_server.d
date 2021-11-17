module libsrpc.rpc_server;

import std.traits;
import libxtrix.io;
import libxk.malloc;
import libxk.hashmap;
import libsrpc.encoder;
import libxk.bytebuffer;
import libxtrix.syscall;

private template digit(uint n) {
	private static const char[] digit = "0123456789"[n .. n+1];
}

private template itoa(uint n) {
	static if(n < 0)
		private static const char[] itoa = "-" ~ itoa!(-n);
	else static if (n < 10)
		private static const char[] itoa = digit!(n);
	else
		private static const char[] itoa = itoa!(n / 10) ~ digit!(n % 10);
}

alias RPCEndpoint = void delegate(XHandle responder, ubyte* data, ulong length, ref ulong offset);

struct RPCListener {
    HashMap!(string, RPCEndpoint) endpoints;
}
private struct DispatcherWrap(Disp, Tplt, string item) {
    Disp* d;
    void wrap(XHandle responder, ubyte* data, ulong length, ref ulong offset) {
    	alias tpv = __traits(getMember, Tplt, item);
		Parameters!(tpv) param;
        static foreach (i; 0 .. param.length) {
            param[i] = decode!(typeof(param[i]))(data, length, offset);
        }
		static if (is(ReturnType!tpv == void)) {
        	__traits(getMember, d, item)(param);
			KeRespond(responder, XHandle(512));
		} else {
			ReturnType!tpv ret = __traits(getMember, d, item)(param);
			auto wrap = encode(ret);
			KeRespond(responder, KeAllocateMemRefObject(wrap.data, wrap.size));
		}
    }
}

RPCListener publish_srpc(Template, Dispatch)(string name, Dispatch* disp) {
    // checks
    static assert(!__traits(compiles, Template()),
        "Type " ~ Template.stringof ~ " must have a disabled constructor because it is not described correctly by it's members");

    // bind class members to RPC
    static foreach (mname; __traits(allMembers, Template)) {{
        // the cast void and borrow is needed for ldc2 to keep the instantion in
        // the instantion is not side-effect-free as it provides linker symbols.
        cast(void)&boundpanic!(Template, mname);
    }}

    RPCListener l;

    static foreach (mname; __traits(allMembers, Template)) {{
    	static if (!(mname[0] == '_' && mname[1] == '_')) {
			RPCEndpoint del = &alloc!(DispatcherWrap!(Dispatch, Template, mname))(disp).wrap;
			l.endpoints[mname] = del;
		}
    }}

    return l;
}

string mangled_fn_name(Obj, string fn)() {
    enum k1 = (&__traits(getMember, Obj, fn)).mangleof;
    static assert(k1[0] == 'P');
    enum k2 = "M" ~ k1[1 .. k1.length];
    enum k3 = Obj.mangleof;
    enum k4 = "_D" ~ k3[1 .. k3.length];
    enum k5 = k4 ~ itoa!(fn.length) ~ fn ~ k2;
    return k5;
}

template boundpanic(Obj, string fn) {
    alias target_fn = __traits(getMember, Obj, fn);

    pragma(mangle, mangled_fn_name!(Obj, fn)()) extern(C)
    ReturnType!target_fn boundpanic(Obj* the_this, Parameters!target_fn args) {
        ByteBuffer omessage;
        omessage << encode(fn);
        static foreach (arg; args) {{
            omessage << encode(arg);
        }}

        foreach (i; 0 .. omessage.size) {
            printf("i: {x}", omessage.data[i]);
        }
        assert(false, "Binding assert to " ~ fn ~ " success!");
    }
}

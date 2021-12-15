module libsrpc.rpc_server;

// libsrpc will recieve a rewrite in the future

import std.traits;
import libxk.list;
import libxtrix.io;
import libxk.malloc;
import libxk.hashmap;
import libsrpc.encoder;
import libxk.bytebuffer;
import libxtrix.syscall;
import libxtrix.libc.malloc;

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

alias RPCEndpoint = void delegate(ulong commxid, ubyte* data, ulong length, ref ulong offset);

struct RPCListener {
	HashMap!(string, RPCEndpoint) endpoints;
	ulong commid;
	
	void attach(ulong id) {
        commid = id;
	}
	void loop() {
		printf("srpc: loop");
		ulong request_pipe = sys_open_pipe(PipeSide.friendship, 0);
		anoerr("sys_open_pipe");

		long childpid = sys_fork();
		if (!childpid) {
			// child
			while (true) {
				ulong commxid = sys_open_pipe(PipeSide.server, commid);
				printf("srpc/acceptworker: client @ {x}", commxid);
				if (!sys_fork()) {
					// child
					while (true) {
						ulong siz;
						sys_recv_data(commxid, &siz, 8);
						anoerr("sys_recv_data");
						printf("rx {x} bytes", siz);
						ubyte* data = cast(ubyte*)malloc(siz);
						sys_recv_data(commxid, data, siz);
						printf("srpc/requestworker: got request!");

						sys_send_data(request_pipe, &siz, 8);
						sys_send_data(request_pipe, &commxid, 8);
						sys_send_data(request_pipe, data, siz);
						free(cast(void*)data);
					}
				}

			}
		} else {
			// parent
			while (true) {
				ulong commxid, siz;
				sys_recv_data(request_pipe, &siz, 8);
				sys_recv_data(request_pipe, &commxid, 8);
				ubyte* data = cast(ubyte*)malloc(siz);
				sys_recv_data(request_pipe, data, siz);

				ulong offset = 0;
				dispatch(data, siz, offset, commxid);
				free(cast(void*)data);
			}
		}
	}
	void dispatch(ubyte* data, ulong length, ref ulong offset, ulong commxid) {
		List!char str = decode!(List!char)(data, length, offset);
		endpoints[cast(string)str.to_slice()](commxid, data, length, offset);
	}
}
private struct DispatcherWrap(Disp, Tplt, string item) {
	Disp* d;
	void wrap(ulong commxid, ubyte* data, ulong length, ref ulong offset) {
		alias tpv = __traits(getMember, Tplt, item);
		Parameters!(tpv) param;
		static foreach (i; 0 .. param.length) {
			param[i] = decode!(typeof(param[i]))(data, length, offset);
		}
		static if (is(ReturnType!tpv == void)) {
			__traits(getMember, d, item)(param);
			ulong len = 0;
			sys_send_data(commxid, &len, ulong.sizeof);
		} else {
			ReturnType!tpv ret = __traits(getMember, d, item)(param);
			auto wrap = encode(ret);
			sys_send_data(commxid, &wrap.size, ulong.sizeof);
			sys_send_data(commxid, wrap.data, wrap.size);
		}
	}
}

RPCListener publish_srpc(Template, Dispatch)(Dispatch* disp) {
	// checks
	static assert(!__traits(compiles, Template()),
			"Type " ~ Template.stringof ~ " must have a disabled constructor because it is not described correctly by its members");

	RPCListener l = RPCListener.init;
	static foreach (mname; __traits(allMembers, Template)) {{
		static if (mname != "close") {
			static if (!(mname[0] == '_' && mname[1] == '_')) {
				RPCEndpoint del = &alloc!(DispatcherWrap!(Dispatch, Template, mname))(disp).wrap;
				l.endpoints[mname] = del;
			}
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

private void hydrate(T)() {
    // bind class members to RPC
    static assert(!__traits(compiles, T()),
        "Type " ~ T.stringof ~ " must have a disabled constructor because it is not described correctly by it's members");
    static assert(__traits(hasMember, T, "close"),
        "Type " ~ T.stringof ~ " must have a close method!");

    static foreach (mname; __traits(allMembers, T)) {{
    	static if (mname[0..2] != "__") {
	        // the cast void and borrow is needed for ldc2 to keep the instantion in.
	        // the instantion is not side-effect-free as it provides linker symbols.
	        cast(void)&bind_to!(T, mname);
	    }
    }}
}

enum SRPC_CHAN = 0x737270636368616e;
enum SRPC_FIND = 0x7372706366696e64;

struct SRPCDispatchTarget {
	ulong magic;
	ulong commxid;
}

T* connect(T)(ulong id) {
	hydrate!(T)();
	long xid = sys_open_pipe(PipeSide.client, id);
    if (xid < 0) anoerr("sys_open_pipe");
	SRPCDispatchTarget* target = cast(SRPCDispatchTarget*)malloc(SRPCDispatchTarget.sizeof);
	target.magic = SRPC_CHAN;
	target.commxid = xid;
	return cast(T*)target;
}

T* connect(T)(string target) {
    InitServerConn* conn = connect!InitServerConn(SRPC_FIND);
    ulong id = conn.id(target);
    conn.close();
    return connect!(T)(id);
}

template bind_to(Obj, string fn) {
    alias target_fn = __traits(getMember, Obj, fn);

    pragma(mangle, mangled_fn_name!(Obj, fn)()) extern(C)
    ReturnType!target_fn bind_to(Obj* the_this, Parameters!target_fn args) {
    	static if (fn == "close") {
    		assert(false, "todo: close channels");
    	} else {
    		SRPCDispatchTarget* cast_this = cast(SRPCDispatchTarget*)the_this;
	    	assert(the_this, "this is null on SRPC method " ~ Obj.stringof ~ "." ~ fn);
    		assert(cast_this.magic == SRPC_CHAN, "Invalid magic for the conn.");
	        ByteBuffer omessage;
	        omessage << encode(fn);
	        static foreach (arg; args) {{
	            omessage << encode(arg);
	        }}

	        foreach (i; 0 .. omessage.size) {
	            printf("i: {x}", omessage.data[i]);
	        }
			ulong rsiz = omessage.size;
			sys_send_data(cast_this.commxid, &rsiz, 8);
			sys_send_data(cast_this.commxid, omessage.data, rsiz);
			sys_recv_data(cast_this.commxid, &rsiz, 8);
	        void* data = malloc(rsiz);
	        sys_recv_data(cast_this.commxid, data, rsiz);
			
			ulong offset = 0;
			return decode!(ReturnType!target_fn)(cast(ubyte*)data, rsiz, offset);
	    }
    }
}

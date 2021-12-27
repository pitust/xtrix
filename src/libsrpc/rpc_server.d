// xtrix srpc server
// Copyright (C) 2021 pitust <piotr@stelmaszek.com>

// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.
module libsrpc.rpc_server;

// FIXME: libsrpc is slow as balls

import std.traits;
import libxk.list;
import libxtrix.io;
import libxk.malloc;
import libxk.hashmap;
import libsrpc.encoder;
import libxk.bytebuffer;
import libxtrix.syscall;
import libxtrix.libc.malloc;

private enum PIPE_REQUEST = 1;
private enum PIPE_RESPONSE = 2;
private enum PIPE_LOCALMSG = 3;

struct InitServerConn {
	this() @disable;
	void close();
	ulong lookup(string name);
	void declare(string name, ulong id);
}

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
alias CloseHandler = void delegate();

struct RPCListener {
	HashMap!(string, RPCEndpoint) endpoints;
	CloseHandler handler = null;
	ulong commid;
	
	void attach(ulong id) {
        commid = id;
	}
	void loop() {
		ulong request_pipe = getpipe(sys_open_pipe(PipeSide.friendship, 0), PIPE_LOCALMSG);
		anoerr("sys_open_pipe");

		long childpid = sys_fork();
		if (!childpid) {
			// child
			while (true) {
				ulong commxid = sys_open_pipe(PipeSide.server, commid);
				long rx = getpipe(commxid, PIPE_REQUEST);
				if (!sys_fork()) {
					// child
					while (true) {
						ulong siz;
						sys_recv_data(rx, &siz, 8); anoerr("sys_recv_data");
						if (siz == 0) {
							sys_close(rx);
							sys_silent_exit();
						}
						ubyte* data = cast(ubyte*)malloc(siz);
						sys_recv_data(rx, data, siz);
						
						void*[3] datavec = [cast(void*)&siz, cast(void*)&commxid, cast(void*)data];
						ulong[3] lenvec = [8, 8, siz];
						sys_send_vectored(request_pipe, datavec, lenvec);
						anoerr("sys_send_vectored");

						free(cast(void*)data);
					}
				}

			}
		} else {
			// parent
			while (true) {
				ulong commxid, siz;
				sys_recv_data(request_pipe, &siz, 8); anoerr("sys_recv_data");
				sys_recv_data(request_pipe, &commxid, 8); anoerr("sys_recv_data");
				ubyte* data = cast(ubyte*)malloc(siz);
				sys_recv_data(request_pipe, data, siz); anoerr("sys_recv_data");

				ulong offset = 0;
				dispatch(data, siz, offset, commxid);
				free(cast(void*)data);
			}
		}
	}
	void dispatch(ubyte* data, ulong length, ref ulong offset, ulong commxid) {
		List!char str = decode!(List!char)(data, length, offset);
		string name = cast(string)str.to_slice();
		if (name == "close") {
			printf("invalid close!");
		}
		if (name in endpoints) {
			endpoints[name](commxid, data, length, offset);
		}
	}
}
private struct DispatcherWrap(Disp, Tplt, string item) {
	Disp* d;
	void wrap(ulong commxid, ubyte* data, ulong length, ref ulong offset) {
		alias tpv = __traits(getMember, Tplt, item);
		Parameters!(tpv) param;
		long tx = getpipe(commxid, PIPE_RESPONSE);
		List!(List!(char)*) tofree;
		static foreach (i; 0 .. param.length) {
			static if (is(typeof(param[i]) : string)) {
				List!(char)* nam = alloc!(List!char)(decode!(List!char)(data, length, offset));
				tofree.append(nam);
				param[i] = cast(string)nam.to_slice();
			} else {
				param[i] = decode!(typeof(param[i]))(data, length, offset);
			}
		}
		static if (is(ReturnType!tpv == void)) {
			__traits(getMember, d, item)(param);
			ulong len = 0;
			sys_send_data(tx, &len, ulong.sizeof); anoerr("sys_send_data");
		} else {
			ReturnType!tpv ret = __traits(getMember, d, item)(param);
			auto wrap = encode(ret);
			sys_send_data(tx, &wrap.size, ulong.sizeof); anoerr("sys_send_data");
			sys_send_data(tx, wrap.data, wrap.size); anoerr("sys_send_data");
		}
	}
}

RPCListener publish_srpc(Template, Dispatch)(Dispatch* disp) {
	// checks
	static assert(!__traits(compiles, Template()),
			"Type " ~ Template.stringof ~ " must have a disabled constructor because it is not described correctly by its members");

	RPCListener l = RPCListener.init;
	static foreach (mname; __traits(allMembers, Template)) {{
		static if (mname != "close" && mname != "onClose") {
			static if (!(mname[0] == '_' && mname[1] == '_')) {
				RPCEndpoint del = &alloc!(DispatcherWrap!(Dispatch, Template, mname))(disp).wrap;
				l.endpoints[mname] = del;
			}
		}
    }}
	static if (__traits(hasMember, disp, "onClose")) {
		l.handler = disp.onClose;
	}

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

enum SRPC_CHAN = 0x737270636368616e; // srpcchan
enum SRPC_FIND = 0x7372706366696e64; // srpcfind

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
	pragma(msg, "hydrate: " ~ fn);

    pragma(mangle, mangled_fn_name!(Obj, fn)()) extern(C)
    ReturnType!target_fn bind_to(Obj* the_this, Parameters!target_fn args) {
    	SRPCDispatchTarget* cast_this = cast(SRPCDispatchTarget*)the_this;
	    assert(the_this, "this is null on SRPC method " ~ Obj.stringof ~ "." ~ fn);
    	assert(cast_this.magic == SRPC_CHAN, "Invalid magic for the conn.");
		long tx = getpipe(cast_this.commxid, PIPE_REQUEST);
		long rx = getpipe(cast_this.commxid, PIPE_RESPONSE);
    	static if (fn == "close") {
    		ulong nil = 0;
			sys_send_data(tx, &nil, 8); anoerr("sys_send_data");
			sys_close(cast_this.commxid);
			free(cast_this);
			return;
    	} else {
	        ByteBuffer omessage;
	        omessage << encode(fn);
	        static foreach (arg; args) {{
	            omessage << encode(arg);
	        }}

			ulong rsiz = omessage.size;
			sys_send_data(tx, &rsiz, 8); anoerr("sys_send_data");
			sys_send_data(tx, omessage.data, rsiz); anoerr("sys_send_data");
			sys_recv_data(rx, &rsiz, 8); anoerr("sys_recv_data");
	        void* data = malloc(rsiz);
	        sys_recv_data(rx, data, rsiz); anoerr("sys_recv_data");
			
			ulong offset = 0;
			return decode!(ReturnType!target_fn)(cast(ubyte*)data, rsiz, offset);
	    }
    }
}

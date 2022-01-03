module libxtrix.events;

import libxtrix.io;
import libxtrix.gc;
import libxtrix.syscall;
import libxtrix.libc.string;

alias RPCPredicate = bool delegate(ulong srcpid, ulong rid, ubyte[] buf) @system;
alias HandlerType = void delegate(ulong srcpid, ulong rid, ubyte[] buf) @system;


private __gshared void delegate() @system[] evl_actions = [];
private __gshared RPCPredicate[] predicates = [];
private __gshared RPCPredicate*[] callbacks = [];
private __gshared bool in_ev_tick = false;
private enum arenaptr = 0x8000_0000;
private __gshared bool mapped_arena = false;
private __gshared bool is_arena_in_use = false;
private __gshared ulong callbacks_hot = 0;

void ev_pump(bool blockx) {
    if (!mapped_arena) {
        sys_mmap(arenaptr, 16*1024);
        mapped_arena = true;
    }
    assert(!is_arena_in_use); is_arena_in_use = true;
    Message msg;
    sys_recvmsg(&msg, cast(void*)arenaptr, 16*1024, blockx);
    if (errno == error.EWOULDBLOCK) {
        is_arena_in_use = false;
        errno = 0;
        return;
    }
    anoerr("sys_recvmsg");
    ubyte[] xfer = alloc_array!(ubyte)(msg.len);
    memcpy(cast(byte*)xfer.ptr, cast(byte*)arenaptr, msg.len);
    is_arena_in_use = false;
    if (msg.rid & 1) {
        ulong subrid = msg.rid >> 1;
        if (subrid >= callbacks.length) {
            printf("warn: bullshit request, rid > len(callbacks)");
            return;
        }
        if (!callbacks[subrid]) {
            printf("warn: bullshit request, callbacks[rid] is null");
            return;
        }
        RPCPredicate* cb = callbacks[subrid];
        callbacks[subrid] = null;
        callbacks_hot--;
        (*cb)(msg.srcpid, msg.rid|1, xfer);
    } else {
        foreach (pred; predicates) {
            if (pred(msg.srcpid, msg.rid|1, xfer)) return;
        }
    }
}
ulong ev_bind_callback(RPCPredicate cbfn) {
    RPCPredicate* pred = alloc!(RPCPredicate)(cbfn);
    callbacks_hot++;
    foreach (i; 0 .. callbacks.length) {
        if (callbacks[i]) continue;
        callbacks[i] = pred;
        return i << 1;
    }
    callbacks = concat(callbacks, pred);
    return (callbacks.length - 1) << 1;
}
void ev_tick() {
    assert(!in_ev_tick, "ev_tick cannot be called in an event context!");
    in_ev_tick = true;
    auto h = evl_actions;
    evl_actions = [];
    foreach (action; h) {
        action();
    }
    in_ev_tick = false;
}
void ev_loop() {
    while (callbacks_hot || predicates.length || evl_actions.length) {
        ev_tick();
        ev_pump(false);
    }
}
void ev_settle() {
    while (evl_actions.length) {
        ev_tick();
    }
}
extern(C) void ev_atexit() {
    if (evl_actions.length != 0 && !in_ev_tick) {
        printf("warning: ev_atexit: unfinished jobs in the event queue! (did you forget to call ev_loop or ev_settle?)");
    }
}

void ev_on(RPCPredicate rp) {
    predicates = concat(predicates, rp);
}

void ev_next_tick(void delegate() @system action) {
    evl_actions = concat(evl_actions, action);
}

enum FutureState {
    pending,
    resolved
}

template _flatten_future(T) {
    static if (is(T U : Future!(Future!U))) {
        static assert("prohibited recursive future!");
    } else static if(is(T U : Future!U)) {
        alias _flatten_future = Future!U;
    } else {
        alias _flatten_future = Future!T;
    }
}
template _future_type(T) {
    static if (is(T U : Future!(Future!U))) {
        static assert("prohibited recursive future!");
    } else static if(is(T U : Future!U)) {
        alias _future_type = U;
    } else {
        alias _future_type = T;
    }
}

_flatten_future!T _do_flatten_future(T)(T delegate() value) {
    static if (is(T U : Future!U)) {
        return value;
    } else {
        _flatten_future!T fut = newFuture!(_future_type!T)();
        ev_next_tick(() { fut.resolve(value()); });
        return fut;
    }
}

struct signal {
    private FutureState state = FutureState.pending;
    private void delegate() dlgt;

    void resolve() {
        assert(state == FutureState.pending, "attempting to resolve a resolved future!");
        state = FutureState.resolved;
        ev_next_tick(() { if (dlgt) dlgt(); });
    }

    Signal then(void delegate() @system cb) {
        Signal sig = newSignal();
        assert(!dlgt);
        if (state == FutureState.pending) {
            dlgt = () {
                cb();
                sig.resolve();
            };
            return sig;
        }
        ev_next_tick(() { cb(); sig.resolve(); });
        return sig;
    }
    _flatten_future!T then(T)(T delegate() @system cb) {
        assert(!dlgt);
        if (state == FutureState.pending) {
            _flatten_future!T fut = newFuture!(_future_type!T)();
            dlgt = () {
                static if (is(T U : Future!U)) {
                    _flatten_future!T fut2 = cb();
                    fut2.then((rval) {
                        fut.resolve(rval);
                    });
                } else {
                    fut.resolve(cb());
                }
            };
            return fut;
        }
        return _do_flatten_future(() => cb());
    }
}
struct future(T) {
    private FutureState state = FutureState.pending;
    private T* value = null;
    private void delegate() @system dlgt;

    void resolve(T val) {
        resolve(val);
    }
    void resolve(ref T val) {
        assert(state == FutureState.pending, "attempting to resolve a resolved future!");
        assert(!value);
        state = FutureState.resolved;
        value = alloc!(T)(val);
        ev_next_tick(() {
            if (dlgt)
                dlgt();
        });
    }

    Signal then(void delegate(ref T val) @system cb) {
        Signal sig = newSignal();
        assert(!dlgt);
        if (state == FutureState.pending) {
            dlgt = () {
                cb(*value);
                sig.resolve();
            };
            return sig;
        }
        ev_next_tick(() { cb(*value); sig.resolve(); });
        return sig;
    }
    _flatten_future!T then(T)(T delegate(ref T val) cb) {
        assert(!dlgt);
        if (state == FutureState.pending) {
            _flatten_future!T fut = newFuture!(_future_type!T)();
            dlgt = () {
                static if (is(T U : Future!U)) {
                    _flatten_future!T fut2 = cb(*value);
                    fut2.then((rval) {
                        fut.resolve(rval);
                    });
                } else {
                    fut.resolve(cb(*value));
                }
            };
            return fut;
        }
        return _do_flatten_future(() => cb(*value));
    }
}

Signal newSignal() {
    return alloc!(signal)();
}
Future!T newFuture(T)() {
    return alloc!(future!(T))();
}

alias Future(T) = future!(T)*;
alias Signal = signal*;

module libxtrix.events;

import libxtrix.io;
import libxtrix.gc;

alias RPCPredicate = bool delegate(ulong pid, ulong rid, ubyte[] buf) @system;
alias HandlerType = void delegate(ulong pid, ulong rid, ubyte[] buf) @system;

private __gshared void delegate() @system[] evl_actions = [];
private __gshared bool in_ev_tick = false;

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
    while (true) {
        ev_tick();
    }
}
extern(C) void ev_atexit() {
    if (evl_actions.length != 0 && !in_ev_tick) {
        printf("warning: ev_atexit: evl still has actions! (did you forget to call ev_loop or ev_settle?)");
    }
}

void ev_on(RPCPredicate rp) {

}

void ev_next_tick(void delegate() @system action) {
    printf("a: {p}", cast(ulong)action.funcptr);
    if (evl_actions.length) printf("R: {}", cast(void*)&evl_actions[0]);
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
        ev_next_tick(() { if (dlgt) dlgt(); });
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

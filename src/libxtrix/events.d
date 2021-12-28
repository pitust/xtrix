module libxtrix.events;

import libxtrix.gc;

alias RPCPredicate = bool delegate(ulong pid, ulong rid, ubyte[] buf) @system;
alias HandlerType = void delegate(ulong pid, ulong rid, ubyte[] buf) @system;

void ev_loop() {
    
}

void ev_on(RPCPredicate rp) {

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

_flatten_future!T _do_flatten_future(T)(T value) {
    static if (is(T U : Future!U)) {
        return value;
    } else {
        _flatten_future!T fut = newFuture!(_future_type!T)();
        fut.resolve(value);
        return fut;
    }
}

struct signal {
    private FutureState state = FutureState.pending;
    private void delegate() dlgt;

    void resolve() {
        assert(state == FutureState.pending, "attempting to resolve a resolved future!");
        state = FutureState.resolved;
        if (dlgt) dlgt();
    }

    Signal then(void delegate() cb) {
        Signal sig = newSignal();
        assert(!dlgt);
        if (state == FutureState.pending) {
            dlgt = () {
                cb();
                sig.resolve();
            };
            return sig;
        }
        cb(); sig.resolve();
        return sig;
    }
    _flatten_future!T then(T)(T delegate() cb) {
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
        return _do_flatten_future(cb());
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
        if (dlgt) dlgt();
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
        cb(*value);
        sig.resolve();
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
                    fut.resolve(cb());
                }
            };
            return fut;
        }
        return _do_flatten_future(cb());
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

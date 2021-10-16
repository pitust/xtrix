module xtrm.io;

import xtrm.atoi;

private uint rgb(ubyte r, ubyte g, ubyte b) {
    return ((cast(uint)r) << 16) | ((cast(uint)g) << 8) | ((cast(uint)b) << 0);
}

extern(C) void ssfnc_cb_scroll(uint* lfb, ulong fb_w, ulong fb_h, ulong fb_p, ulong scrollby) {
    foreach (line; scrollby..fb_h) {
        foreach (x; 0..fb_w) {
            (cast(uint*)(lfb))[(line - scrollby) * (fb_p / 4) + x]
                = (cast(uint*)(lfb))[line * (fb_p / 4) + x];
        }
    }
    foreach (line; (fb_h - scrollby)..fb_h) {
        foreach (x; 0..fb_w) {
            (cast(uint*)(lfb))[line * (fb_p / 4) + x] = BLACK;
        }
    }
}

private enum RED = rgb(250, 25, 68);
private enum GREEN = rgb(0, 208, 52);
private enum YELLOW = rgb(255, 230, 89);
private enum BLUE = rgb(0, 114, 255);
private enum PURPLE = rgb(170, 119, 244);
private enum CYAN = rgb(0, 190, 199);
private enum WHITE = rgb(198, 203, 210);
private enum BLACK = rgb(23, 27, 30);

extern(C) void ssfnc_do_init(void* src, void* lfb, uint w, uint h, uint p);

extern(C) void ssfnc_do_getstats(ushort* w, ushort* h, ushort* fb_w, ushort* fb_h, ushort* fb_p, void** lfb);
extern(C) void ssfnc_do_getcursor(ushort* x, ushort* y);
extern(C) void ssfnc_do_setcursor(ushort x, ushort y);

extern(C) void ssfnc_do_getcolor(uint* bg, uint* fg);
extern(C) void ssfnc_do_setcolor(uint bg, uint fg);

extern(C) int ssfnc_putc(uint chr);

__gshared bool fonts_init = false;
__gshared bool serial_printk_ctx = false;
void io_fonts_initialized() {
    fonts_init = true;
    ushort _bs, fb_w, fb_h, fb_p;
    void* lfb;
    ssfnc_do_getstats(&_bs, &_bs, &fb_w, &fb_h, &fb_p, &lfb);

    // foreach (y; 0..fb_h) {
    //     foreach (x; 0..fb_w) {
    //         foreach (xxx; 1..5) {
    //             ulong xt = (x * y + x * 9) % fb_w;
    //             ulong yt = (y - x + fb_h * 3) % fb_h;
    //             xt *= xxx; xt %= fb_w;
    //             yt *= xxx; yt %= fb_h;
    //             (cast(uint*)(lfb))[(yt & ~1) * (fb_p / 4) + (xt & ~1)] = BLACK;
    //             (cast(uint*)(lfb))[(yt & ~1) * (fb_p / 4) + (xt | 1)] = BLACK;

    //             (cast(uint*)(lfb))[(yt | 1) * (fb_p / 4) + (xt & ~1)] = BLACK;
    //             (cast(uint*)(lfb))[(yt | 1) * (fb_p / 4) + (xt | 1)] = BLACK;
    //         }
    //     }
    // }
    foreach (y; 0..fb_h) {
        foreach (x; 0..fb_w) {
            (cast(uint*)(lfb))[y * (fb_p / 4) + x] = BLACK;
        }
    }
}
void outb(ushort port, ubyte value) {
    asm {
        mov DX, port;
        mov AL, value;
        out DX, AL;
    }
}
private uint colorchr(char c) {
    if ((c & 0x60) == 0x60) c ^= 0x20;
    if ((c >= 'A' && c <= 'Z') || (c == '0')) {
        if (c == 'R') return /* red */ RED;
        if (c == 'G') return /* green */ GREEN;
        if (c == 'Y') return /* yellow */ YELLOW;
        if (c == 'B') return /* blue */ BLUE;
        if (c == 'P') return /* purple */ PURPLE;
        if (c == 'C') return /* cyan */ CYAN;
        if (c == 'W') return /* white */ WHITE;
        if (c == '0') return /* black */ BLACK;
        return /* error color */ 0xFF_00_FF;
    } else {
        return /* error color */ 0xFF_00_FF;
    }
}
private __gshared int cmode = 0;
private bool handle_xtrm_escape_fsm(char c, uint* bgcol, uint* fgcol) {
    *bgcol = ~0;
    *fgcol = ~0;

    if (c == '\x1b') {
        cmode = 1;
        return true;
    }
    if (cmode == 1 || cmode == 2) {
        if (c == '_') {
            cmode = 2;
            return true;
        }
        if (c == '/') {
            *bgcol = 0; *fgcol = WHITE;
            cmode = 0;
            return false;
        }
        if (c == '[') {
            return true;
        }
        if (c == ']') {
            cmode = 0;
            return true;
        }
        if (cmode == 1) *fgcol = colorchr(c);
        else *bgcol = colorchr(c);
        cmode = 1;
        return true;
    }
    return false;
}
private void putc(char c) {
    if (serial_printk_ctx) {
        nographics_putc(c);
        return;
    }
    uint bgcol, fgcol;
    if (handle_xtrm_escape_fsm(c, &bgcol, &fgcol)) {
        uint fg, bg;
        ssfnc_do_getcolor(&bg, &fg);
        if (fgcol != ~0) {
            ubyte r = cast(ubyte)(fgcol >> 16);
            ubyte g =  cast(ubyte)(fgcol >> 8);
            ubyte b =  cast(ubyte)(fgcol >> 0);
            if (fgcol == 0xFF_FF_FF || fgcol == WHITE) {
                serial_printf("\x1b[37m");
            } else {
                serial_printf("\x1b[38;2;{};{};{}m", r, g, b);
            }
            fg = fgcol;
        }
        if (bgcol != ~0) {
            ubyte r = cast(ubyte)(bgcol >> 16);
            ubyte g =  cast(ubyte)(bgcol >> 8);
            ubyte b =  cast(ubyte)(bgcol >> 0);
            if (bgcol == 0 || bgcol == BLACK) {
                ubyte fgr = cast(ubyte)(fg >> 16);
                ubyte fgg =  cast(ubyte)(fg >> 8);
                ubyte fgb =  cast(ubyte)(fg >> 0);
                if (fg == 0xFF_FF_FF || fg == WHITE) {
                    serial_printf("\x1b[0m\x1b[37m");
                } else {
                    serial_printf("\x1b[0m\x1b[38;2;{};{};{}m", fgr, fgg, fgb);
                }
            } else {
                serial_printf("\x1b[48;2;{};{};{}m", r, g, b);
            }
            bg = bgcol;
        }
        if (fonts_init) {
            ssfnc_do_setcolor(bg, fg);
        }
    } else {
        nographics_putc(c);
        if (fonts_init) {
            ssfnc_putc(c);
        }
    }
}
private void nographics_putc(char c) {
    outb(0xe9, c);
}
void putchar(char c) {
    hide_fucking_cursor();
    putc(c);
    show_fucking_cursor();
}
void puts(const(char)* str) {
    hide_fucking_cursor();
    while (*str) putc(*str++);
    putc('\n');
    show_fucking_cursor();
}
void printvalue(const(char)* str) {
    while (*str) putc(*str++);
}
void printvalue(IOTuple!ulong value) {
    if (value.fmt == "fmt/bytes") {
        if (value.value > 0x20000000000) {
            value.value /= 0x10000000000;
            printvalue(value.value);
            printvalue("TB");
        } else if (value.value > 0x80000000) {
            value.value /= 0x40000000;
            printvalue(value.value);
            printvalue("GB");
        } else if (value.value > 0x200000) {
            value.value /= 0x100000;
            printvalue(value.value);
            printvalue("MB");
        } else if (value.value > 0x800) {
            value.value /= 0x400;
            printvalue(value.value);
            printvalue(" KB");
        } else {
            printvalue(value.value);
            printvalue(" bytes");
        }
        return;
    }

    printvalue("<unknown ulong formatter "); printvalue(value.fmt); printvalue(">");
}
void printvalue(const(char)[] str) {
    foreach (char chr; str) putc(chr);
}
void printvalue(immutable(char)[] str) {
    foreach (char chr; str) putc(chr);
}
void printvalue(long l) {
    sprinti(l, 10, 0, " ", "", &putc, "", "", "", "", "");
}
void printhexvalue(long l) {
    sprinti(l, 16, 0, " ", "0x", &putc, "", "", "", "", "");
}
void printptrvalue(long l) {
    sprinti(l, 16, 16, "0", "0x", &putc, "", "", "", "", "");
}

void flip_cursor() {
    assert(fonts_init);
    ushort w, h, x, y, fbw, fbh, fbp;
    uint* lfb;
    ssfnc_do_getstats(&w, &h, &fbw, &fbh, &fbp, cast(void**)&lfb);
    ssfnc_do_getcursor(&x, &y);
    w = h / 2;
    for (int xoff = 0;xoff < w;xoff++) {
        for (int yoff = 0;yoff < h;yoff++) {
            lfb[(x + xoff) + (y + yoff) * (fbp / 4)] ^= 0xFFFFFF;
        }
    }
    isCursorShown = !isCursorShown;
}

struct IOTuple(T) {
    string fmt;
    T value;
}
IOTuple!(T) iotuple(T)(string fmt, T value) {
    return IOTuple!(T)(fmt, value);
}

private __gshared bool isCursorShown = false;
/// hides the fucking cursor. must call before writing text
void hide_fucking_cursor() {
    if (!fonts_init) return;
    if (isCursorShown) flip_cursor();
}
/// shows the fucking cursor. must call after writing text
void show_fucking_cursor() {
    if (!fonts_init) return;
    if (!isCursorShown) flip_cursor();
}

private void do_printk(bool newline, Args...)(string s, Args args) {
    enum Mode {
        HEX,
        NORMAL,
        PTR,
        PRINTED
    }
    if (!serial_printk_ctx) hide_fucking_cursor();
    ulong si = 0;
    static foreach (arg; args) {{
        Mode m = Mode.NORMAL;
        while (true) {
            if (s[si + 0] == '{' && s[si + 1] == '}') {
                si += 2;
                break;
            }
            if (s[si + 0] == '{' && s[si + 1] == 'x' && s[si + 2] == '}') {
                si += 3;
                m = Mode.HEX;
                break;
            }
            if (s[si + 0] == '{' && (s[si + 1] == 'p' || s[si + 1] == '*') && s[si + 2] == '}') {
                si += 3;
                m = Mode.PTR;
                break;
            }
            if (s.length <= si) break;
            putc(s[si]);
            si++;
        }
        static if (__traits(compiles, printvalue(arg))) {
            if (m == Mode.NORMAL) {
                printvalue(arg);
                m = Mode.PRINTED;
            }
        }
        static if (__traits(compiles, printhexvalue(arg))) {
            if (m == Mode.HEX) {
                printhexvalue(arg);
                m = Mode.PRINTED;
            }
        }
        static if (__traits(compiles, printptrvalue(arg))) {
            if (m == Mode.PTR) {
                printptrvalue(arg);
                m = Mode.PRINTED;
            }
        }
        static if (
            true
            && !__traits(compiles, printvalue(arg))
            && !__traits(compiles, printhexvalue(arg))
            && !__traits(compiles, printptrvalue(arg))) {
            pragma(msg, "===================================");
            pragma(msg, "  Cannot compile printk formats!");
            pragma(msg, "");
            pragma(msg, "============== normal =============");
            printvalue(arg);
            pragma(msg, "=============== hex ===============");
            printhexvalue(arg);
            pragma(msg, "=============== ptr ===============");
            printptrvalue(arg);
            pragma(msg, "===================================");
        }
        if (m != Mode.PRINTED) {
            if (m == Mode.HEX)
                assert(m == Mode.PRINTED, "Failed to print hexally for this type");
            if (m == Mode.NORMAL)
                assert(m == Mode.PRINTED, "Failed to print normally for this type");
            if (m == Mode.PTR)
                assert(m == Mode.PRINTED, "Failed to print as pointer for this type");
            assert(m == Mode.PRINTED, "Failed to print (WTF)");
        }
    }}
    while (true) {
        if (s.length <= si) break;
        putc(s[si]);
        si++;
    }
    if (fonts_init) {
        ssfnc_do_setcolor(0, 0xFF_FF_FF);
    }
    if (!serial_printk_ctx) {
        nographics_putc('\x1b'); nographics_putc('['); nographics_putc('0'); nographics_putc('m');
    }
    static if (newline) putc('\n');
    if (!serial_printk_ctx) show_fucking_cursor();
}
void printk(Args...)(string s, Args args) {
    do_printk!(true, Args)(s, args);
}
void printf(Args...)(string s, Args args) {
    do_printk!(false, Args)(s, args);
}
private void serial_printf(Args...)(string s, Args args) {
    bool fi = serial_printk_ctx;
    serial_printk_ctx = true;
    do_printk!(false, Args)(s, args);
    serial_printk_ctx = fi;
}
private void serial_printk(Args...)(string s, Args args) {
    bool fi = serial_printk_ctx;
    serial_printk_ctx = true;
    do_printk!(true, Args)(s, args);
    serial_printk_ctx = fi;
}
module xtrm.io;

import xtrm.atoi;


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
        if (c == 'R') return /* red */ 0xFF_00_00;
        if (c == 'G') return /* green */ 0x00_FF_00;
        if (c == 'B') return /* blue */ 0x00_00_FF;
        if (c == 'Y') return /* yellow */ 0x00_FF_FF;
        if (c == 'W') return /* white */ 0xFF_FF_FF;
        if (c == '0') return /* black */ 0x00_00_00;
        return /* purple */ 0xFF_00_FF;
    } else {
        return /* purple */ 0xFF_00_FF;
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
            *bgcol = 0; *fgcol = 0xFF_FF_FF;
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
            if (fgcol == 0xFF_FF_FF) {
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
            if (bgcol == 0) {
                ubyte fgr = cast(ubyte)(fg >> 16);
                ubyte fgg =  cast(ubyte)(fg >> 8);
                ubyte fgb =  cast(ubyte)(fg >> 0);
                if (fg == 0xFF_FF_FF) {
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
void printvalue(const(char)[] str) {
    foreach (char chr; str) putc(chr);
}
void printvalue(long l) {
    char[64] buf;
    printvalue(intToString(l, buf.ptr, 10));
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

void printk(Args...)(string s, Args args) {
    hide_fucking_cursor();
    ulong si = 0;
    static foreach (arg; args) {
        while (true) {
            if (s[si + 0] == '{' && s[si + 1] == '}') {
                si += 2;
                break;
            }
            if (s.length <= si) break;
            putc(s[si]);
            si++;
        }
        printvalue(arg);
    }
    while (true) {
        if (s.length <= si) break;
        putc(s[si]);
        si++;
    }
    if (fonts_init) {
        ssfnc_do_setcolor(0, 0xFF_FF_FF);
    }
    nographics_putc('\x1b'); nographics_putc('['); nographics_putc('0'); nographics_putc('m');
    putc('\n');
    show_fucking_cursor();
}
void printf(Args...)(string s, Args args) {
    hide_fucking_cursor();
    ulong si = 0;
    static foreach (arg; args) {
        while (true) {
            if (s[si + 0] == '{' && s[si + 1] == '}') {
                si += 2;
                break;
            }
            if (s.length <= si) break;
            putc(s[si]);
            si++;
        }
        printvalue(arg);
    }
    while (true) {
        if (s.length <= si) break;
        putc(s[si]);
        si++;
    }
    if (fonts_init) {
        ssfnc_do_setcolor(0, 0xFF_FF_FF);
    }
    nographics_putc('\x1b'); nographics_putc('['); nographics_putc('0'); nographics_putc('m');
    show_fucking_cursor();
}
private void serial_printf(Args...)(string s, Args args) {
    ulong si = 0;
    bool fi = serial_printk_ctx;
    serial_printk_ctx = true;
    static foreach (arg; args) {
        while (true) {
            if (s[si + 0] == '{' && s[si + 1] == '}') {
                si += 2;
                break;
            }
            if (s.length <= si) break;
            nographics_putc(s[si]);
            si++;
        }
        printvalue(arg);
    }
    while (true) {
        if (s.length <= si) break;
        nographics_putc(s[si]);
        si++;
    }
    serial_printk_ctx = fi;
}
private void serial_printk(Args...)(string s, Args args) {
    ulong si = 0;
    bool fi = serial_printk_ctx;
    serial_printk_ctx = true;
    static foreach (arg; args) {
        while (true) {
            if (s[si + 0] == '{' && s[si + 1] == '}') {
                si += 2;
                break;
            }
            if (s.length <= si) break;
            nographics_putc(s[si]);
            si++;
        }
        printvalue(arg);
    }
    while (true) {
        if (s.length <= si) break;
        nographics_putc(s[si]);
        si++;
    }
    nographics_putc('\n');
    serial_printk_ctx = fi;
}
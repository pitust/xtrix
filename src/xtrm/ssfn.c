// scalable-font2 glue for xtrix
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
#define SSFN_CONSOLEBITMAP_TRUECOLOR
#define NULL ((void*)(0))
#include <stdint.h>
#include <ssfn.h>

void ssfnc_do_init(void* src, void* lfb, uint32_t w, uint32_t h, uint32_t p) {
	ssfn_src = src;
	ssfn_dst.ptr = lfb;                         /* address of the linear frame buffer */
	ssfn_dst.w = w;                          /* width */
	ssfn_dst.h = h;                           /* height */
	ssfn_dst.p = p;                          /* bytes per line */
	ssfn_dst.x = ssfn_dst.y = 0;                /* pen position */
	ssfn_dst.fg = 0xFFFFFF;                     /* foreground color */
	ssfn_dst.bg = 0x000000;
}
void ssfnc_cb_scroll(void*, uint64_t fb_w, uint64_t fb_h, uint64_t fb_p, uint64_t by);
int ssfnc_putc(uint32_t c) {
	if (ssfn_dst.x >= ssfn_dst.w) {
		int e = ssfn_putc('\n');
		if (e) return e;
	}
	int e = ssfn_putc(c);
	if (e) return e;
	if (ssfn_dst.x >= ssfn_dst.w) {
		int e = ssfn_putc('\n');
		if (e) return e;
	}
	if (ssfn_dst.y >= ssfn_dst.h) {
		ssfnc_cb_scroll(ssfn_dst.ptr, ssfn_dst.w, ssfn_dst.h, ssfn_dst.p, ssfn_src->height);
		ssfn_dst.y -= ssfn_src->height;
	}
	return 0;
}
void ssfnc_do_getcursor(int16_t* x, int16_t* y) {
	*x = ssfn_dst.x;
	*y = ssfn_dst.y;
}
void ssfnc_do_setcursor(int16_t x, int16_t y) {
	ssfn_dst.x = x;
	ssfn_dst.y = y;
}
void ssfnc_do_getstats(int16_t* w, int16_t* h, int16_t* fb_w, int16_t* fb_h, int16_t* fb_p, void** lfb) {
	*w = ssfn_src->width;
	*h = ssfn_src->height;
	*lfb = ssfn_dst.ptr;
	*fb_w = ssfn_dst.w;
	*fb_h = ssfn_dst.h;
	*fb_p = ssfn_dst.p;
}
void ssfnc_do_getcolor(uint32_t* bg, uint32_t* fg) {
	*fg = ssfn_dst.fg;
	*bg = ssfn_dst.bg;
}
void ssfnc_do_setcolor(uint32_t bg, uint32_t fg) {
	ssfn_dst.fg = fg;
	ssfn_dst.bg = bg;
}

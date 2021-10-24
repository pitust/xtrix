// xtrix intager to string convertion routines
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
module xtrm.atoi;

private void outputs(const(char)* s, void function(char) output) {
    while (*s) output(*s++);
}

/// pretty print a number with many configuration options
/// 
/// Params:
///   value = the value to print
///   base = the base in which to print the number
///   pad = the minimum amount of characters the output must be
///   padding = the string to use for padding
///   prefix = prefix to put before the number
///   output = output function
///   reset = sequence to reset terminal settings
///   before_prefix = sequence used before the prefix
///   before_padding = sequence used before the padding
///   before_padding_if_was_zero = sequence used before the padding if it was zero
///   before_number = sequence used before the number itself
void sprinti(num)(
    num value,                                 // the value to print
    int base,                                   // the base in which to print the number
    ulong pad,                                  // the minimum amount of characters the output must be
    string padding,                             // the string to use for padding
    const(char)* prefix,                        // prefix to put before the number
    void function(char) output,                 // output function
    const(char)* reset,                         // sequence to reset terminal settings
    const(char)* before_prefix,                 // sequence used before the prefix
    const(char)* before_padding,                // sequence used before the padding
    const(char)* before_padding_if_was_zero,    // sequence used before the padding if it was zero
    const(char)* before_number,                 // sequence used before the number itself
) {
    outputs(before_prefix, output);
    while (*prefix) output(*prefix++);
    outputs(reset, output);
    char[100] buf;
    ulong i = 100;
    ulong chars = 0;
    bool numberWasZero = false;
    if (value < 0) {
        value = -value;
        output('-');
    }
    if (!value) {
        buf[--i] = '0';
        chars++;
        numberWasZero = true;
    }
    bool dig = false;
    while (value) {
        buf[--i] = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"[value % base];
        value /= base;
        chars++;
        dig = !dig;
    }
    ulong padi = 0;
    if (dig &&base == 16 && pad == 0) buf[--i] = '0';
    if (numberWasZero) {
        if (base == 16 && pad == 0) buf[--i] = '0';
        outputs(before_padding_if_was_zero, output);
        while ((chars + padi) < pad) output(padding[padi++ % padding.length]);
        outputs(reset, output);
    } else {
        outputs(before_padding, output);
        while ((chars + padi) < pad) output(padding[padi++ % padding.length]);
        outputs(reset, output);
    }

    outputs(before_number, output);
    while (i < 100) {
        output(buf[i++]);
    }
    outputs(reset, output);
}
module xtrm.kdbg;

import xtrm.io;

enum COM1 = 0x3F8;

bool serial_init() {
	outb(COM1 + 1, 0x00);    // Disable all interrupts
	outb(COM1 + 3, 0x80);    // Enable DLAB (set baud rate divisor)
	outb(COM1 + 0, 0x01);    // Set divisor to 1 (lo byte) 115200 baud
	outb(COM1 + 1, 0x00);    //                  (hi byte)
	outb(COM1 + 3, 0x03);    // 8 bits, no parity, one stop bit
	outb(COM1 + 2, 0xC7);    // Enable FIFO, clear them, with 14-byte threshold
	outb(COM1 + 4, 0x0B);    // IRQs enabled, RTS/DSR set
	outb(COM1 + 4, 0x1E);    // Set in loopback mode, test the serial chip
	outb(COM1 + 0, 0xAE);    // Test serial chip (send byte 0xAE and check if serial returns same byte)

	// Check if serial is faulty (i.e: not same byte as sent)
	if(inb(COM1 + 0) != 0xAE) {
		return true;
	}

	// If serial is not faulty set it in normal operation mode
	// (not-loopback with IRQs enabled and OUT#1 and OUT#2 bits enabled)
	outb(COM1 + 4, 0x0F);
	return false;
}


bool serial_received() {
	// printk("x: {x}", inb(COM1 + 5));
	return (inb(COM1 + 5) & 1) != 0;
}
 
char read_serial() {
	assert(serial_received(), "read_serial: invariant not met: serial_received() is false");
	return inb(COM1);
}


int is_transmit_empty() {
	return inb(COM1 + 5) & 0x20;
}
 
private __gshared bool _serial_ssfn = false;
private extern(C) bool write_serial(char a) {
	if (!_serial_ssfn) return false;
	while (is_transmit_empty() == 0) {}
	outb(COM1,a);
	return true;
}

__gshared char[64] buf;
__gshared ulong idx = 0;

private void kdbg_print_serial(Args...)(Args args) {
	_printf(args);
}
void kdbg_attach() {
	kdbg_print_serial("kd> ");
}
void kdbg_step() {
	write_serial('x');
	if (serial_received()) {
		char c = read_serial();
		printk("kdbg_step: step {x}", cast(ubyte)c);
		if (c == /* C-] aka KDI */ '\x1c') {
			kdbg_attach();
		}
		buf[idx++ & 0x1f] = c;
	}
}


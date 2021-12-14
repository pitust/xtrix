module xtrm.kdbg;

import xtrm.io;
import xtrm.user.syscalls;

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
	outb(COM1, a);
	return true;
}
private void txser(char c) {
	while (is_transmit_empty() == 0) {}
	outb(COM1, c);
}
private char rxser() {
	while (!serial_received()) {}
	return read_serial();
}

__gshared char[64] buf;
__gshared ulong idx = 0;

private void kdbg_print_serial(Args...)(Args args) {
	_serial_ssfn = true;
	serial_printf(args);
	_serial_ssfn = false;
}

struct Task {
	string name;
	void function(char[] cmdbuf) exec;
}

void help_task(char[] cmdbuf) {
	kdbg_print_serial("this is kd, the xtrix kernel debugger. use 'quit' to exit kd\n");
}
void _tasklist(char[] cmdbuf) {
	_serial_ssfn = true;
	syscalls_task_list();
	_serial_ssfn = false;
}

private __gshared immutable(Task)[] task_registry = [
	Task("help", &help_task),
	Task("tl", &_tasklist)
];

private void run_task(char[] cmdbuf) {
	foreach (ref task; task_registry) {
		if (cmdbuf[0 .. task.name.length] == task.name) {
			if (cmdbuf[task.name.length] == 0 || cmdbuf[task.name.length] == ' ') 
				return task.exec(cmdbuf[task.name.length + 1 .. $]);
		}
	}
	kdbg_print_serial("Unknown command!\n");
}

void kdbg_attach() {
	__gshared char[128] cmd;
	while (true) {
		kdbg_print_serial("kd> ");
		ulong off = 0;
		while (off < 128) {
			char c = rxser();
			if (c == '\x1d' || c == '\x04') {
				if (off == 0) {
					kdbg_print_serial("\nBye.\n");
					return;
				}
				off = 0;
				kdbg_print_serial("<lmao>");
				break;
			}
			if (c == '\x1b') { rxser(); rxser(); } // pls be enough
			txser(c);
			if (c == '\r') break;
			cmd[off++] = c;
		}
		kdbg_print_serial("\n");
		if (off == 128) { continue; }
		if (cmd[0 .. off] == "quit") {
			kdbg_print_serial("Bye.\n");
			break;
		}
		cmd[off++] = 0;
		if (off == 1) continue;
		run_task(cmd);
	}
}
void kdbg_step() {
	if (serial_received()) {
		char c = read_serial();
		if (c == /* C-] aka KDI */ '\x1d') {
			kdbg_attach();
		}
		buf[idx++ & 0x1f] = c;
	}
}


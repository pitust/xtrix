module libxk.date;


private ulong get_jdn(uint days, uint months, uint years) {
	return (1461 * (years + 4800 + (months - 14)/12))/4 + (367 *
		   (months - 2 - 12 * ((months - 14)/12)))/12 -
		   (3 * ((years + 4900 + (months - 14)/12)/100))/4
		   + days - 32075;
}

private ulong get_unix_epoch(uint seconds, uint minutes, uint  hours,
							   uint days,    uint months,  uint years) {
	ulong jdn_current = get_jdn(days, months, years);
	ulong jdn_1970    = get_jdn(1, 1, 1970);

	ulong jdn_diff = jdn_current - jdn_1970;

	return (jdn_diff * (60 * 60 * 24)) + hours * 3600 + minutes * 60 + seconds;
}

private uint calc_year(ulong epoch) {
	foreach (year; 1970 .. 9999) {
		if (epoch < get_unix_epoch(0, 0, 0, 1, 1, year)) return year - 1;
	}
	assert(false, "change calc_year to support over yr9999");
}
private uint calc_month(ulong epoch, uint year) {
	foreach (month; cast(ubyte)1 .. 12) {
		if (epoch < get_unix_epoch(0, 0, 0, 31, month, year)) return month;
	}
	assert(false, "wtf");
}
private uint calc_day(ulong epoch, uint year, uint month) {
	foreach (day; 1 .. 31) {
		if (epoch < get_unix_epoch(0, 0, 0, day, month, year)) return day - 1;
	}
	assert(false, "wtf");
}


enum string[12] months = [
	"January", "February", "March", "April", "May", "June", "July",
	"August", "September", "Octobrer", "November", "December"];
	
void epoch2date(ulong epoch, out uint year, out uint month, out uint day, out uint hour, out uint minute, out uint second) {
	year = cast(uint)(calc_year(epoch));
	month = cast(uint)(calc_month(epoch, year));
	day = cast(uint)(calc_day(epoch, year, month));
	ulong offset = cast(uint)((epoch - get_unix_epoch(0, 0, 0, day, month, year)));
	hour = cast(uint)(offset / 3600);
	minute = cast(uint)(offset / 60 % 60);
	second = cast(uint)(offset % 60);
}

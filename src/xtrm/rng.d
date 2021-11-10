module xtrm.rng;

__gshared ulong value = 0x9e3779b97f4a7c15;

private ulong mmhash_mix(ulong value) {
    value ^= value >> 33;
    value *= 0xFF51AFD7ED558CCD;
    value ^= value >> 33;
    value *= 0xC4CEB9FE1A85EC53;
    value ^= value >> 33;
    return value;
}
private ulong mmhash_mix2(ulong value) {
    value ^= value >> 33;
    value *= 0xC4CEB9FE1A85EC53;
    value ^= value >> 33;
    value *= 0xFF51AFD7ED558CCD;
    value ^= value >> 33;
    return value;
}
ulong random_ulong() {
    value = mmhash_mix(value);
    ulong res = mmhash_mix(value);
    value = mmhash_mix2(value);
    return res;
}
ulong random_aslr() {
    ulong res = random_ulong();
    res &= 0x0000_07ff_fff0_0000;
    res |= 0x0000_7800_0000_0000;
    return res;
}
void random_mixseed(ulong seed) {
    value = mmhash_mix(mmhash_mix(seed) ^ mmhash_mix(value));
}
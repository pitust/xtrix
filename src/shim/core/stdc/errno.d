module core.stdc.errno;

enum EOK = 0;
enum EACCES = -1;
enum ENOSYS = -2;
enum EAGAIN = -3;
enum EFAULT = -4;
enum EINVAL = -5;
enum EWOULDBLOCK = -6;
__gshared extern(C) long errno;
extern(C) void setErrno(long errno);
extern(C) long getErrno();


#define _GNU_SOURCE
#include <sys/socket.h>
#include <sys/un.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <poll.h>
#include <fcntl.h>
#include <errno.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <unistd.h>
#define P(name,val) printf("%s=%lld\n", name, (long long)(val))
int main(void){
P("AF_UNIX",AF_UNIX);P("SOCK_STREAM",SOCK_STREAM);P("SOCK_DGRAM",SOCK_DGRAM);P("SOCK_SEQPACKET",SOCK_SEQPACKET);P("SOCK_CLOEXEC",SOCK_CLOEXEC);
P("SOL_SOCKET",SOL_SOCKET);P("SO_SNDBUF",SO_SNDBUF);P("SO_RCVBUF",SO_RCVBUF);P("SO_PASSCRED",SO_PASSCRED);P("SO_PEERCRED",SO_PEERCRED);P("SCM_RIGHTS",SCM_RIGHTS);P("SCM_CREDENTIALS",SCM_CREDENTIALS);
P("MSG_CTRUNC",MSG_CTRUNC);P("MSG_TRUNC",MSG_TRUNC);P("MSG_NOSIGNAL",MSG_NOSIGNAL);P("MSG_CMSG_CLOEXEC",MSG_CMSG_CLOEXEC);
P("F_GETFD",F_GETFD);P("F_SETFD",F_SETFD);P("F_GETFL",F_GETFL);P("F_SETFL",F_SETFL);P("F_DUPFD_CLOEXEC",F_DUPFD_CLOEXEC);P("FD_CLOEXEC",FD_CLOEXEC);P("O_NONBLOCK",O_NONBLOCK);P("O_PATH",O_PATH);P("O_NOFOLLOW",O_NOFOLLOW);
P("POLLIN",POLLIN);P("POLLPRI",POLLPRI);P("POLLOUT",POLLOUT);P("POLLERR",POLLERR);P("POLLHUP",POLLHUP);P("POLLNVAL",POLLNVAL);
P("ENOTSOCK",ENOTSOCK);P("EINVAL",EINVAL);P("ENAMETOOLONG",ENAMETOOLONG);P("EMSGSIZE",EMSGSIZE);P("EAGAIN",EAGAIN);P("EWOULDBLOCK",EWOULDBLOCK);P("EINTR",EINTR);
P("SHUT_RD",SHUT_RD);P("SHUT_WR",SHUT_WR);P("SHUT_RDWR",SHUT_RDWR);
P("SOCKADDR_UN_SIZE",sizeof(struct sockaddr_un));P("SOCKADDR_UN_ALIGNMENT",_Alignof(struct sockaddr_un));P("SUN_FAMILY_OFFSET",offsetof(struct sockaddr_un,sun_family));P("SUN_PATH_OFFSET",offsetof(struct sockaddr_un,sun_path));P("SUN_PATH_CAPACITY",sizeof(((struct sockaddr_un*)0)->sun_path));P("SA_FAMILY_SIZE",sizeof(sa_family_t));P("SOCKLEN_SIZE",sizeof(socklen_t));
P("IOVEC_SIZE",sizeof(struct iovec));P("IOVEC_ALIGNMENT",_Alignof(struct iovec));P("IOV_BASE_OFFSET",offsetof(struct iovec,iov_base));P("IOV_LEN_OFFSET",offsetof(struct iovec,iov_len));
P("MSGHDR_SIZE",sizeof(struct msghdr));P("MSGHDR_ALIGNMENT",_Alignof(struct msghdr));P("MSG_NAME_OFFSET",offsetof(struct msghdr,msg_name));P("MSG_NAMELEN_OFFSET",offsetof(struct msghdr,msg_namelen));P("MSG_IOV_OFFSET",offsetof(struct msghdr,msg_iov));P("MSG_IOVLEN_OFFSET",offsetof(struct msghdr,msg_iovlen));P("MSG_CONTROL_OFFSET",offsetof(struct msghdr,msg_control));P("MSG_CONTROLLEN_OFFSET",offsetof(struct msghdr,msg_controllen));P("MSG_FLAGS_OFFSET",offsetof(struct msghdr,msg_flags));
P("POLLFD_SIZE",sizeof(struct pollfd));P("POLLFD_ALIGNMENT",_Alignof(struct pollfd));P("POLLFD_FD_OFFSET",offsetof(struct pollfd,fd));P("POLLFD_EVENTS_OFFSET",offsetof(struct pollfd,events));P("POLLFD_REVENTS_OFFSET",offsetof(struct pollfd,revents));
P("CMSGHDR_SIZE",sizeof(struct cmsghdr));P("CMSGHDR_ALIGNMENT",_Alignof(struct cmsghdr));P("CMSG_LEN_OFFSET",offsetof(struct cmsghdr,cmsg_len));P("CMSG_LEVEL_OFFSET",offsetof(struct cmsghdr,cmsg_level));P("CMSG_TYPE_OFFSET",offsetof(struct cmsghdr,cmsg_type));P("CMSG_DATA_OFFSET",(char*)CMSG_DATA((struct cmsghdr*)0)-(char*)0);P("CMSG_ALIGN_UNIT",sizeof(size_t));
P("UCRED_SIZE",sizeof(struct ucred));P("UCRED_PID_OFFSET",offsetof(struct ucred,pid));P("UCRED_UID_OFFSET",offsetof(struct ucred,uid));P("UCRED_GID_OFFSET",offsetof(struct ucred,gid));
P("STAT_SIZE",sizeof(struct stat));P("STAT_ALIGNMENT",_Alignof(struct stat));P("STAT_DEV_OFFSET",offsetof(struct stat,st_dev));P("STAT_INO_OFFSET",offsetof(struct stat,st_ino));P("STAT_MODE_OFFSET",offsetof(struct stat,st_mode));P("STAT_UID_OFFSET",offsetof(struct stat,st_uid));P("STAT_GID_OFFSET",offsetof(struct stat,st_gid));P("S_IFMT",S_IFMT);P("S_IFSOCK",S_IFSOCK);P("MODE_MASK",07777);
P("INT_SIZE",sizeof(int));P("SIZE_T_SIZE",sizeof(size_t));P("FD_SIZE",sizeof(int));P("PID_T_SIZE",sizeof(pid_t));P("UID_T_SIZE",sizeof(uid_t));P("GID_T_SIZE",sizeof(gid_t));
P("UID_T_MAX",(uid_t)-1);P("GID_T_MAX",(gid_t)-1);
return 0;}

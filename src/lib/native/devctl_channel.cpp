#include "devctl_channel.h"
#include "tcl_util.h"

#include <cstring>
#include <fcntl.h>
#include <sstream>
#include <stdexcept>
#include <string>
#include <sys/socket.h>
#include <sys/un.h>
#include <tcl.h>
#include <unistd.h>

using namespace vessel;

namespace
{

class devctl_socket
{
    static const std::string DEVCTL_PATH = "/var/run/devd.seqpacket.pipe";
    fd_guard m_fd;

    int open_devctl()
    {
        struct sockaddr_un devd_addr;
        int error;

        /*Connect to devd's seq packet pipe*/
        memset(&devd_addr, 0, sizeof(devd_addr));
        devd_addr.sun_family = PF_LOCAL;
        strlcpy(devd_addr.sun_path, DEVCTL_PATH.c_str(), sizeof(devd_addr.sun_path));
        fd_guard s(socket(PF_LOCAL, SOCK_SEQPACKET, 0));

        error = connect(s.fd, (struct sockaddr*)&devd_addr, SUN_LEN(&devd_addr));
        if(error == -1)
        {
            std::ostringstream msg;
            msg << "Error connecting to " << DEVCTL_PATH << ": " << strerror(error);
            throw std::runtime_error(msg.str());
        }

        return s.release();
    }

    public:

    devctl_socket()
        : m_fd(open_devctl())
    {}

    ~devctl_socket()
    {}
};
}

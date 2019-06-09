#include <arpa/inet.h>
#include <cstdio>
#include <cstdlib>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <iostream>
#include <cstring>
#include <cerrno>
#include <unistd.h>

#include <list>
#include <string>

namespace  {

void check_error(const std::string& context)
{
    perror(context.c_str());
    exit(1);
}

struct dns_header
{
    uint16_t id;
    bool qr;
    uint8_t opcode;
    bool aa;
    bool tc;
    bool rd;
    bool ra;
    uint8_t z;
    uint8_t rcode;
    uint16_t qdcount;
    uint16_t ancount;
    uint16_t nscount;
    uint16_t arcount;

    dns_header(char* data, size_t size)
    {
        id = ntohs(*((uint16_t*)&data[0]));

        qr = data[2] & 0x80;
        opcode = (data[2] >> 4) & 0x0f;
        aa = (data[2] >> 3) & 0x01;
        tc = (data[2] >> 1) & 0x01;
        rd = data[2] & 0x01;

        ra = (data[3] >> 7) & 0x01;
        z = (data[3] >> 4) & 0x07;
        rcode = data[3] & 0x0f;

        qdcount = ntohs(*((uint16_t*)&data[4]));
        ancount = ntohs(*((uint16_t*)&data[6]));
        nscount = ntohs(*((uint16_t*)&data[8]));
        arcount = ntohs(*((uint16_t*)&data[10]));
    }
};

struct dns_query : dns_header
{

    std::string qname;

    uint16_t qtype;
    uint16_t qclass;
    dns_query(char* data, size_t size)
        : dns_header(data, size)
    {
        size_t current_offset = 12;
        while(data[current_offset] != 0x0)
        {
            if(qname.length() > 0)
            {
                qname.append(".");
            }
            size_t label_len = data[current_offset++];
            std::string label(&data[current_offset], label_len);
            qname.append(label);
            current_offset += label_len;
        }

        current_offset++;
        qtype = ntohs(*((uint16_t*)&data[current_offset]));

        current_offset += 2;
        qclass = ntohs(*((uint16_t*)&data[current_offset]));
    }
};
}
int main(int argc, char** argv)
{
    //TODO: RAII
    int fd = ::socket(AF_INET,
                      SOCK_DGRAM | SOCK_CLOEXEC,
                      0);

    if(fd == -1) check_error("socket");

    sockaddr_in addr;
    memset(&addr, 0, sizeof(addr));
    addr.sin_len = sizeof(addr);
    addr.sin_family = AF_INET;
    addr.sin_port = htons(53);

    int error = inet_pton(AF_INET, "192.168.1.112", &addr.sin_addr);
    if(error == -1)  check_error("inet_pton");

    error = ::bind(fd, (sockaddr*)&addr, sizeof(addr));
    if(error == -1) check_error("bind");

    char buf[2048];
    memset(buf, 0, sizeof(buf));
    ssize_t bytes_received = ::recv(fd, buf, sizeof(buf), 0);

    std::cerr << "Hey bytes received: " << bytes_received << ", " << strerror(errno) << std::endl;

    dns_query query(buf, bytes_received);
    std::cerr << "ID: " << query.id << std::endl;
    std::cerr << "QR: " << query.qr << std::endl;
    std::cerr << "RD: " << query.rd << std::endl;
    std::cerr << "QD: " << query.qdcount << std::endl;
    std::cerr << "AN: " << query.ancount << std::endl;
    std::cerr << "NS: " << query.nscount << std::endl;
    std::cerr << "AR: " << query.arcount << std::endl;
    std::cerr << "QNAME: " << query.qname << std::endl;
    std::cerr << "QTYPE: " << query.qtype << std::endl;
    std::cerr << "QCLASS: " << query.qclass << std::endl;

    ::write(fileno(stdout), buf, bytes_received);
    exit(0);
}

#include <arpa/inet.h>
#include <array>
#include <cerrno>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <iostream>
#include <netinet/in.h>
#include <sstream>
#include <string>
#include <sys/types.h>
#include <sys/socket.h>
#include <unistd.h>
#include <vector>

namespace  {

void check_error(const std::string& context)
{
    perror(context.c_str());
    exit(1);
}

struct dns_header
{
    static const int SIZE = 12; /**< Num bytes in a header*/

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

    dns_header(const unsigned char* data, size_t size)
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

    dns_header()
        : id(0),
          qr(0),
          opcode(0),
          aa(0),
          tc(0),
          rd(0),
          ra(0),
          z(0),
          rcode(0),
          qdcount(0),
          ancount(0),
          nscount(0),
          arcount(0)
    {

    }

    bool is_query() const
    {
        return (qr == 0);
    }

    dns_header& set_id(uint16_t id)
    {
        this->id = id;
        return *this;
    }

    dns_header& set_response(bool is_response)
    {
        qr = is_response;
        return *this;
    }

    dns_header& set_opcode(uint8_t opcode)
    {
        this->opcode = opcode;
        return *this;
    }

    dns_header& set_authoritative(bool authoritative)
    {
        this->aa = authoritative;
        return *this;
    }

    dns_header& set_truncation(bool truncated)
    {
        this->tc = truncated;
        return *this;
    }

    dns_header& set_recursion_desired(bool recursion)
    {
        this->rd = recursion;
        return *this;
    }

    dns_header& set_recursion_available(bool recursion_available)
    {
        this->ra = recursion_available;
        return *this;
    }

    dns_header& set_response_code(uint8_t rcode)
    {
        this->rcode = rcode;
        return *this;
    }

    dns_header& set_question_count(uint16_t qdcount)
    {
        this->qdcount = qdcount;
        return *this;
    }

    dns_header& set_answer_count(uint16_t ancount)
    {
        this->ancount = ancount;
        return *this;
    }

    dns_header& set_nscount(uint16_t nscount)
    {
        this->nscount = nscount;
        return *this;
    }

    dns_header& set_additional_records_count(uint16_t arcount)
    {
        this->arcount = arcount;
        return *this;
    }

    void serialize(unsigned char* buf, size_t buf_size)
    {
        if(buf_size < 12)
        {
            throw std::invalid_argument("buf size to serialize header is < 12");
        }

        memset(buf, 0, buf_size);

        buf[0] = (id & 0xff00) >> 8;
        buf[1] = id & 0x00ff;
        buf[2] |= (qr << 7);
        buf[2] |= (opcode & 0x0f) << 6;
        buf[2] |= aa << 2;
        buf[2] |= tc << 1;
        buf[2] |= rd << 0;
        buf[3] |= ra << 7;
        buf[3] |= z << 6 & 0x07;
        buf[3] |= rcode & 0xf;
        buf[4] = (qdcount & 0xff00) >> 8;
        buf[5] = qdcount & 0x00ff;
        buf[6] = (ancount & 0xff00) >> 8;
        buf[7] = ancount & 0x00ff;
        buf[8] = (nscount & 0xff00) >> 8;
        buf[9] = nscount & 0x00ff;
        buf[10] = (arcount & 0xff00) >> 8;
        buf[11] = arcount & 0x00ff;
    }
};

class dns_message
{
    static const int MAX_SIZE = 512;
protected:
    std::vector<unsigned char> raw_bytes;

    dns_header m_header;

    dns_message(const unsigned char* buf, size_t msg_size)
        : raw_bytes(buf, buf + msg_size),
          m_header(buf, msg_size)
    {}
public:

    dns_message()
        : raw_bytes(),
          m_header()
    {
        raw_bytes.reserve(MAX_SIZE);
    }

    const dns_header& header() const
    {
        return m_header;
    }
};

struct dns_query : public dns_message
{
    std::string qname; /**< Queried name*/

    uint16_t qtype; /**< Query type*/

    uint16_t qclass; /**< Query class*/
    dns_query(const unsigned char* data, size_t size)
        : dns_message(data, size)
    {
        size_t current_offset = dns_header::SIZE;
        while(data[current_offset] != 0x0)
        {
            if(qname.length() > 0)
            {
                qname.append(".");
            }
            size_t label_len = data[current_offset++];
            std::string label((char*)&data[current_offset], label_len);
            qname.append(label);
            current_offset += label_len;
        }

        current_offset++;
        qtype = ntohs(*((uint16_t*)&data[current_offset]));

        current_offset += 2;
        qclass = ntohs(*((uint16_t*)&data[current_offset]));
    }
};

struct dns_A_response : public dns_message
{
    std::string name;
    in_addr_t addr;
    uint32_t ttl;

    dns_A_response(uint16_t id,
                   const std::string& name,
                   in_addr_t result_addr,
                   uint32_t ttl)
        : dns_message(),
          name(name),
          addr(result_addr),
          ttl(ttl)
    {
        //TODO: A few more of these values need to come from the request
        m_header.set_id(id)
                .set_response(true)
                .set_opcode(0)
                .set_authoritative(true)
                .set_recursion_desired(false)
                .set_truncation(false)
                .set_recursion_available(false)
                .set_response_code(0)
                .set_question_count(1)
                .set_answer_count(1)
                .set_nscount(0)
                .set_additional_records_count(0);
    }

    size_t serialize(std::array<uint8_t, 512>& msg_buf,
                     const unsigned char* query, size_t query_size)
    {
        size_t bytes_used = 0;
        memset(msg_buf.data(), 0, msg_buf.size());
        m_header.serialize(msg_buf.data(), dns_header::SIZE);
        bytes_used = dns_header::SIZE;

        for(int i = dns_header::SIZE; i < query_size; ++i)
        {
            msg_buf[bytes_used++] = query[i];
        }

        /*We currently only support one domain name lookup.  So we
         * can hardcode this value*/
        msg_buf[bytes_used++] = 0xc0;
        msg_buf[bytes_used++] = 0x0c;

        msg_buf[bytes_used++] = 0x00; //A record
        msg_buf[bytes_used++] = 0x01;

        msg_buf[bytes_used++] = 0x00; //INTERNET record
        msg_buf[bytes_used++] = 0x01;

        msg_buf[bytes_used++] = (ttl & 0xff << 24) >> 24;
        msg_buf[bytes_used++] = (ttl & 0xff << 16) >> 16;
        msg_buf[bytes_used++] = (ttl & 0xff << 8) >> 8;
        msg_buf[bytes_used++] = (ttl & 0xff << 0) >> 0;

        /*We only support ipv4 for now*/
        msg_buf[bytes_used++] = 0x00; //rdlength
        msg_buf[bytes_used++] = 0x04;

        msg_buf[bytes_used++] = (addr & (0xff << 0)) >> 0;
        msg_buf[bytes_used++] = (addr & (0xff << 8)) >> 8;
        msg_buf[bytes_used++] = (addr & (0xff << 16)) >> 16;
        msg_buf[bytes_used++] = (addr & (0xff << 24)) >> 24;
        return bytes_used;
    }
};


}

/*TODO: Remove this and use as library with process_packet
 * and generate response calls.*/
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

    unsigned char query_buf[512]; //512 is the max dns datagram
    memset(query_buf, 0, sizeof(query_buf));

    sockaddr_in from_addr;
    memset(&from_addr, 0, sizeof(from_addr));
    socklen_t from_len = sizeof(from_addr);
    ssize_t query_size = ::recvfrom(fd, query_buf, sizeof(query_buf), 0,
                                   (sockaddr*)&from_addr, &from_len);

    std::cerr << "Hey bytes received: " << query_size << ", "
              << strerror(errno) << ", "
              << "From: " << inet_ntoa(from_addr.sin_addr) << std::endl;

    dns_header header(query_buf, query_size);

    ::write(fileno(stdout), query_buf, query_size);

    if(header.is_query())
    {
        dns_query query(query_buf, query_size);
        std::cerr << "ID: " << query.header().id << std::endl;
        std::cerr << "QR: " << query.header().qr << std::endl;
        std::cerr << "RD: " << query.header().rd << std::endl;
        std::cerr << "QD: " << query.header().qdcount << std::endl;
        std::cerr << "AN: " << query.header().ancount << std::endl;
        std::cerr << "NS: " << query.header().nscount << std::endl;
        std::cerr << "AR: " << query.header().arcount << std::endl;
        std::cerr << "QNAME: " << query.qname << std::endl;
        std::cerr << "QTYPE: " << query.qtype << std::endl;
        std::cerr << "QCLASS: " << query.qclass << std::endl;

        in_addr_t resolved_address;
        error = inet_pton(AF_INET, "192.168.3.7", &resolved_address);
        if(error <= 0)
        {
            check_error("parse dest");
        }

        dns_A_response response(header.id, query.qname, resolved_address, 10);
        std::array<uint8_t, 512> response_pkt;
        size_t response_size = response.serialize(response_pkt, query_buf, query_size);
        std::cerr << "Response size: " << response_size << std::endl;
        std::cout << "||" << std::endl;
        ::write(fileno(stdout), response_pkt.data(), response_size);
        sendto(fd, response_pkt.data(), response_size, 0, (sockaddr*)&from_addr, from_len);
    }
    exit(0);
}

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

#include "embdns.h"

using namespace embdns;

dns_header::dns_header(const unsigned char* data, size_t size)
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

dns_header::dns_header()
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
{}

bool dns_header::is_query() const
{
    return (qr == 0);
}

dns_header& dns_header::set_id(uint16_t id)
{
    this->id = id;
    return *this;
}

dns_header& dns_header::set_response(bool is_response)
{
    qr = is_response;
    return *this;
}

dns_header& dns_header::set_opcode(uint8_t opcode)
{
    this->opcode = opcode;
    return *this;
}

dns_header& dns_header::set_authoritative(bool authoritative)
{
    this->aa = authoritative;
    return *this;
}

dns_header& dns_header::set_truncation(bool truncated)
{
    this->tc = truncated;
    return *this;
}

dns_header& dns_header::set_recursion_desired(bool recursion)
{
    this->rd = recursion;
    return *this;
}

dns_header& dns_header::set_recursion_available(bool recursion_available)
{
    this->ra = recursion_available;
    return *this;
}

dns_header& dns_header::set_response_code(uint8_t rcode)
{
    this->rcode = rcode;
    return *this;
}

dns_header& dns_header::set_question_count(uint16_t qdcount)
{
    this->qdcount = qdcount;
    return *this;
}

dns_header& dns_header::set_answer_count(uint16_t ancount)
{
    this->ancount = ancount;
    return *this;
}

dns_header& dns_header::set_nscount(uint16_t nscount)
{
    this->nscount = nscount;
    return *this;
}

dns_header& dns_header::set_additional_records_count(uint16_t arcount)
{
    this->arcount = arcount;
    return *this;
}

void dns_header::serialize(unsigned char* buf, size_t buf_size)
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

dns_message::dns_message(const unsigned char* buf, size_t msg_size)
    : raw_bytes(buf, buf + msg_size),
      m_header(buf, msg_size)
{}

dns_message::dns_message()
    : raw_bytes(),
      m_header()
{
    raw_bytes.reserve(MAX_SIZE);
}

const dns_header& dns_message::header() const
{
    return m_header;
}

dns_query::dns_query(const unsigned char* data, size_t size)
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

const std::vector<unsigned char>& dns_query::raw() const
{
    return raw_bytes;
}

dns_A_response::dns_A_response(uint16_t id,
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

size_t dns_A_response::serialize(std::array<uint8_t, 512>& msg_buf,
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


dns_query embdns::parse_packet(const uint8_t* pkt, size_t size)
{
    return dns_query(pkt, size);
}

size_t embdns::generate_response(std::array<uint8_t, dns_message::MAX_SIZE>& pkt_buf,
                               dns_query& assoc_query, /*Corresponding query*/
                               const std::string& address,
                               uint32_t ttl)
{
    in_addr_t net_addr = inet_addr(address.c_str());
    dns_A_response response(assoc_query.header().id, assoc_query.qname,
                            net_addr, ttl);
    return response.serialize(pkt_buf, assoc_query.raw().data(), assoc_query.raw().size());
}

/*TODO: Support SRV and TXT for service discovery and service
 * configuration*/

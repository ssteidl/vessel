#ifndef EMBDNS_H
#define EMBDNS_H

#include <array>
#include <string>
#include <sys/types.h>
#include <vector>

namespace embdns {

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

        dns_header();
        dns_header(const unsigned char* data, size_t size);
        bool is_query() const;

        dns_header& set_id(uint16_t id);

        dns_header& set_response(bool is_response);

        dns_header& set_opcode(uint8_t opcode);

        dns_header& set_authoritative(bool authoritative);

        dns_header& set_truncation(bool truncated);

        dns_header& set_recursion_desired(bool recursion);

        dns_header& set_recursion_available(bool recursion_available);

        dns_header& set_response_code(uint8_t rcode);

        dns_header& set_question_count(uint16_t qdcount);

        dns_header& set_answer_count(uint16_t ancount);

        dns_header& set_nscount(uint16_t nscount);

        dns_header& set_additional_records_count(uint16_t arcount);

        void serialize(unsigned char* buf, size_t buf_size);
    };

    class dns_message
    {
    public:
        static const int MAX_SIZE = 512;
    protected:
        std::vector<unsigned char> raw_bytes;

        dns_header m_header;

        dns_message(const unsigned char* buf, size_t msg_size);
    public:

        dns_message();

        const dns_header& header() const;
    };

    struct dns_query : public dns_message
    {
        std::string qname; /**< Queried name*/

        uint16_t qtype; /**< Query type*/

        uint16_t qclass; /**< Query class*/

        dns_query(const unsigned char* data, size_t size);

        const std::vector<unsigned char>& raw() const;
    };

    struct dns_A_response : public dns_message
    {
        std::string name;
        in_addr_t addr;
        uint32_t ttl;

        /**Empty response*/
        dns_A_response(uint16_t id,
                       const std::string& name);

        dns_A_response(uint16_t id,
                       const std::string& name,
                       in_addr_t result_addr,
                       uint32_t ttl);

        size_t serialize(std::array<uint8_t, 512>& msg_buf,
                         const unsigned char* query, size_t query_size);
    };

    dns_query parse_packet(const uint8_t* pkt, size_t size);


    size_t generate_response(std::array<uint8_t, dns_message::MAX_SIZE>& pkt_buf,
                             dns_query& assoc_query);

    size_t generate_response(std::array<uint8_t, dns_message::MAX_SIZE>& pkt_buf,
                             dns_query& assoc_query, /*Corresponding query*/
                             const std::string& address,
                             uint32_t ttl);
}
#endif // EMBDNS_H

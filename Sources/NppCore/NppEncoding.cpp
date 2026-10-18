#include "NppEncoding.h"
#include "uchardet/uchardet.h"
#include <iconv.h>
#include <cstring>
#include <cstdlib>
#include <algorithm>
#include <vector>
#include <string>

static std::string normalize_charset_name(const std::string& name) {
    std::string s = name;
    std::transform(s.begin(), s.end(), s.begin(), ::toupper);
    if (s == "EUC-KR" || s == "CP949" || s == "WINDOWS-949" || s == "MS949") {
        return "CP949";
    }
    if (s == "SHIFT_JIS" || s == "SJIS" || s == "CP932") {
        return "CP932";
    }
    if (s == "GB2312" || s == "GBK" || s == "GB18030") {
        return "GB18030";
    }
    if (s == "BIG5" || s == "CP950") {
        return "BIG5";
    }
    if (s == "ISO-8859-1" || s == "WINDOWS-1252" || s == "CP1252" || s == "ANSI") {
        return "WINDOWS-1252";
    }
    if (s == "UTF-8" || s == "UTF8" || s == "ASCII" || s == "US-ASCII") {
        return "UTF-8";
    }
    return s;
}

static NppEncodingType map_charset_to_enum(const std::string& name, bool hasBOM) {
    if (hasBOM) {
        if (name == "UTF-8") return NppEncodingType::UTF8_BOM;
        if (name == "UTF-16LE") return NppEncodingType::UTF16_LE;
        if (name == "UTF-16BE") return NppEncodingType::UTF16_BE;
    }
    if (name == "UTF-8") return NppEncodingType::UTF8;
    if (name == "CP949" || name == "EUC-KR") return NppEncodingType::CP949_EUCKR;
    if (name == "CP932" || name == "SHIFT_JIS") return NppEncodingType::SHIFT_JIS;
    if (name == "GB18030" || name == "GB2312" || name == "GBK") return NppEncodingType::GB2312;
    if (name == "BIG5") return NppEncodingType::BIG5;
    if (name == "WINDOWS-1252" || name == "ISO-8859-1") return NppEncodingType::WINDOWS_1252;
    if (name == "UTF-16LE") return NppEncodingType::UTF16_LE;
    if (name == "UTF-16BE") return NppEncodingType::UTF16_BE;
    return NppEncodingType::ANSI;
}

static NppEolFormat detect_eol(const char* data, size_t length) {
    size_t crlf_count = 0;
    size_t lf_count = 0;
    size_t cr_count = 0;

    for (size_t i = 0; i < length; ++i) {
        if (data[i] == '\r') {
            if (i + 1 < length && data[i + 1] == '\n') {
                crlf_count++;
                i++; // skip \n
            } else {
                cr_count++;
            }
        } else if (data[i] == '\n') {
            lf_count++;
        }
    }

    if (crlf_count >= lf_count && crlf_count >= cr_count && crlf_count > 0) {
        return NppEolFormat::CRLF;
    }
    if (cr_count > lf_count && cr_count > crlf_count) {
        return NppEolFormat::CR;
    }
    return NppEolFormat::LF; // default to Unix LF on mac if ambiguous
}

extern "C" {

NppBridgeDetectionResult npp_detect_encoding_and_eol(const char* data, size_t length) {
    NppBridgeDetectionResult res;
    res.encodingType = static_cast<int>(NppEncodingType::UTF8);
    res.charsetName = "UTF-8";
    res.hasBOM = 0;
    res.eolFormat = static_cast<int>(detect_eol(data, length));

    if (length == 0 || data == nullptr) {
        return res;
    }

    const unsigned char* udata = reinterpret_cast<const unsigned char*>(data);

    // 1. Check BOM
    if (length >= 3 && udata[0] == 0xEF && udata[1] == 0xBB && udata[2] == 0xBF) {
        res.hasBOM = 1;
        res.charsetName = "UTF-8";
        res.encodingType = static_cast<int>(NppEncodingType::UTF8_BOM);
        return res;
    }
    if (length >= 2 && udata[0] == 0xFF && udata[1] == 0xFE) {
        res.hasBOM = 1;
        res.charsetName = "UTF-16LE";
        res.encodingType = static_cast<int>(NppEncodingType::UTF16_LE);
        return res;
    }
    if (length >= 2 && udata[0] == 0xFE && udata[1] == 0xFF) {
        res.hasBOM = 1;
        res.charsetName = "UTF-16BE";
        res.encodingType = static_cast<int>(NppEncodingType::UTF16_BE);
        return res;
    }

    // 2. Check for pure ASCII or valid UTF-8 without BOM first
    bool is_valid_utf8 = true;
    size_t i = 0;
    size_t non_ascii = 0;
    while (i < length) {
        unsigned char c = udata[i];
        if (c <= 0x7F) {
            i++;
        } else if ((c & 0xE0) == 0xC0) {
            non_ascii++;
            if (i + 1 >= length || (udata[i + 1] & 0xC0) != 0x80) { is_valid_utf8 = false; break; }
            i += 2;
        } else if ((c & 0xF0) == 0xE0) {
            non_ascii++;
            if (i + 2 >= length || (udata[i + 1] & 0xC0) != 0x80 || (udata[i + 2] & 0xC0) != 0x80) { is_valid_utf8 = false; break; }
            i += 3;
        } else if ((c & 0xF8) == 0xF0) {
            non_ascii++;
            if (i + 3 >= length || (udata[i + 1] & 0xC0) != 0x80 || (udata[i + 2] & 0xC0) != 0x80 || (udata[i + 3] & 0xC0) != 0x80) { is_valid_utf8 = false; break; }
            i += 4;
        } else {
            is_valid_utf8 = false;
            break;
        }
    }

    if (is_valid_utf8 && non_ascii == 0) {
        // Pure ASCII, default to UTF-8
        res.charsetName = "UTF-8";
        res.encodingType = static_cast<int>(NppEncodingType::UTF8);
        return res;
    }

    // 3. Run Mozilla uchardet (Notepad++ internal engine)
    uchardet_t ud = uchardet_new();
    uchardet_handle_data(ud, data, length);
    uchardet_data_end(ud);
    const char* detected = uchardet_get_charset(ud);
    std::string charset = (detected && *detected) ? detected : "";
    uchardet_delete(ud);

    std::string norm = normalize_charset_name(charset);
    if (!norm.empty()) {
        static char stored_name[64];
        std::strncpy(stored_name, norm.c_str(), sizeof(stored_name) - 1);
        stored_name[sizeof(stored_name) - 1] = '\0';
        res.charsetName = stored_name;
        res.encodingType = static_cast<int>(map_charset_to_enum(norm, false));
        return res;
    }

    if (is_valid_utf8) {
        res.charsetName = "UTF-8";
        res.encodingType = static_cast<int>(NppEncodingType::UTF8);
    } else {
        // Default legacy fallback for Korean/East Asian Windows
        res.charsetName = "CP949";
        res.encodingType = static_cast<int>(NppEncodingType::CP949_EUCKR);
    }

    return res;
}

char* npp_decode_to_utf8(const char* data, size_t length, const char* charsetName, int* outLength) {
    if (!data || length == 0) {
        if (outLength) *outLength = 0;
        char* empty = static_cast<char*>(malloc(1));
        empty[0] = '\0';
        return empty;
    }

    // Skip BOM if present
    const unsigned char* udata = reinterpret_cast<const unsigned char*>(data);
    size_t offset = 0;
    if (length >= 3 && udata[0] == 0xEF && udata[1] == 0xBB && udata[2] == 0xBF) {
        offset = 3;
    } else if (length >= 2 && ((udata[0] == 0xFF && udata[1] == 0xFE) || (udata[0] == 0xFE && udata[1] == 0xFF))) {
        offset = 2;
    }
    const char* src_ptr = data + offset;
    size_t src_len = length - offset;

    std::string from_enc = normalize_charset_name(charsetName ? charsetName : "UTF-8");
    if (from_enc == "UTF-8") {
        char* out = static_cast<char*>(malloc(src_len + 1));
        std::memcpy(out, src_ptr, src_len);
        out[src_len] = '\0';
        if (outLength) *outLength = static_cast<int>(src_len);
        return out;
    }

    iconv_t cd = iconv_open("UTF-8//IGNORE", from_enc.c_str());
    if (cd == (iconv_t)-1) {
        // Try fallback to standard iconv name if failed
        cd = iconv_open("UTF-8", from_enc.c_str());
    }
    if (cd == (iconv_t)-1) {
        // Fallback: return raw bytes
        char* out = static_cast<char*>(malloc(src_len + 1));
        std::memcpy(out, src_ptr, src_len);
        out[src_len] = '\0';
        if (outLength) *outLength = static_cast<int>(src_len);
        return out;
    }

    // Allocate 4x capacity for UTF-8 expansion
    size_t out_cap = src_len * 4 + 16;
    char* out_buf = static_cast<char*>(malloc(out_cap));
    char* in_buf_ptr = const_cast<char*>(src_ptr);
    char* out_buf_ptr = out_buf;
    size_t in_left = src_len;
    size_t out_left = out_cap - 1;

    size_t res = iconv(cd, &in_buf_ptr, &in_left, &out_buf_ptr, &out_left);
    iconv_close(cd);

    size_t produced = (out_cap - 1) - out_left;
    out_buf[produced] = '\0';
    if (outLength) *outLength = static_cast<int>(produced);
    return out_buf;
}

char* npp_encode_from_utf8(const char* utf8Str, size_t utf8Len, const char* charsetName, int addBOM, size_t* outLength) {
    if (!utf8Str) {
        if (outLength) *outLength = 0;
        return nullptr;
    }

    std::string to_enc = normalize_charset_name(charsetName ? charsetName : "UTF-8");
    std::vector<uint8_t> result;

    if (addBOM) {
        if (to_enc == "UTF-8") {
            result.push_back(0xEF);
            result.push_back(0xBB);
            result.push_back(0xBF);
        } else if (to_enc == "UTF-16LE") {
            result.push_back(0xFF);
            result.push_back(0xFE);
        } else if (to_enc == "UTF-16BE") {
            result.push_back(0xFE);
            result.push_back(0xFF);
        }
    }

    if (to_enc == "UTF-8") {
        result.insert(result.end(), utf8Str, utf8Str + utf8Len);
    } else {
        iconv_t cd = iconv_open(to_enc.c_str(), "UTF-8");
        if (cd == (iconv_t)-1) {
            result.insert(result.end(), utf8Str, utf8Str + utf8Len);
        } else {
            size_t out_cap = utf8Len * 4 + 32;
            std::vector<char> temp_out(out_cap);
            char* in_ptr = const_cast<char*>(utf8Str);
            char* out_ptr = temp_out.data();
            size_t in_left = utf8Len;
            size_t out_left = out_cap;

            iconv(cd, &in_ptr, &in_left, &out_ptr, &out_left);
            iconv_close(cd);

            size_t converted = out_cap - out_left;
            result.insert(result.end(), temp_out.data(), temp_out.data() + converted);
        }
    }

    size_t final_len = result.size();
    char* final_buf = static_cast<char*>(malloc(final_len + 1));
    std::memcpy(final_buf, result.data(), final_len);
    final_buf[final_len] = '\0';
    if (outLength) *outLength = final_len;
    return final_buf;
}

char* npp_convert_eol(const char* utf8Str, size_t utf8Len, int targetEol, size_t* outLength) {
    if (!utf8Str) {
        if (outLength) *outLength = 0;
        return nullptr;
    }

    std::string out;
    out.reserve(utf8Len + utf8Len / 10);

    const char* eol_seq = "\n";
    if (targetEol == static_cast<int>(NppEolFormat::CRLF)) {
        eol_seq = "\r\n";
    } else if (targetEol == static_cast<int>(NppEolFormat::CR)) {
        eol_seq = "\r";
    }

    for (size_t i = 0; i < utf8Len; ++i) {
        if (utf8Str[i] == '\r') {
            if (i + 1 < utf8Len && utf8Str[i + 1] == '\n') {
                out.append(eol_seq);
                i++; // skip \n
            } else {
                out.append(eol_seq);
            }
        } else if (utf8Str[i] == '\n') {
            out.append(eol_seq);
        } else {
            out.push_back(utf8Str[i]);
        }
    }

    size_t res_len = out.size();
    char* res_buf = static_cast<char*>(malloc(res_len + 1));
    std::memcpy(res_buf, out.data(), res_len);
    res_buf[res_len] = '\0';
    if (outLength) *outLength = res_len;
    return res_buf;
}

void npp_free_string(char* str) {
    if (str) free(str);
}

void npp_free_buffer(char* buf) {
    if (buf) free(buf);
}

}

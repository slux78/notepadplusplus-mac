#ifndef NPP_ENCODING_H
#define NPP_ENCODING_H

#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
#include <string>
#include <vector>
#include <cstdint>
#include <cstddef>

enum class NppEncodingType {
    ANSI = 0,
    UTF8,
    UTF8_BOM,
    UTF16_LE,
    UTF16_BE,
    CP949_EUCKR,
    SHIFT_JIS,
    GB2312,
    BIG5,
    WINDOWS_1252,
    UNKNOWN
};

enum class NppEolFormat {
    CRLF = 0, // Windows (\r\n)
    LF,       // Unix / macOS (\n)
    CR        // Classic Mac (\r)
};

struct NppDetectionResult {
    NppEncodingType encoding;
    std::string charsetName;
    bool hasBOM;
    NppEolFormat eolFormat;
};
#endif

#ifdef __cplusplus
extern "C" {
#endif

// C-compatible struct for Swift bridging
typedef struct {
    int encodingType; // corresponds to NppEncodingType
    const char* charsetName;
    int hasBOM;
    int eolFormat; // corresponds to NppEolFormat
} NppBridgeDetectionResult;

// Public C API for Swift
NppBridgeDetectionResult npp_detect_encoding_and_eol(const char* data, size_t length);

// Decode raw file bytes into UTF-8 string for UI display/editing
// Returns newly allocated null-terminated UTF-8 string (must be freed with npp_free_string)
char* npp_decode_to_utf8(const char* data, size_t length, const char* charsetName, int* outLength);

// Encode UTF-8 string to target charset bytes for saving to disk
// Returns newly allocated byte buffer (must be freed with npp_free_buffer)
char* npp_encode_from_utf8(const char* utf8Str, size_t utf8Len, const char* charsetName, int addBOM, size_t* outLength);

// Convert EOL in UTF-8 string
char* npp_convert_eol(const char* utf8Str, size_t utf8Len, int targetEol, size_t* outLength);

void npp_free_string(char* str);
void npp_free_buffer(char* buf);

#ifdef __cplusplus
}
#endif

#endif // NPP_ENCODING_H

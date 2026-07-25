#include "XGGzip.h"

#include <stdlib.h>
#include <string.h>
#include <limits.h>
#include <zlib.h>

enum { XG_GZIP_INITIAL_CAPACITY = 32768, XG_GZIP_MAX_OUTPUT = 256 * 1024 * 1024 };

int xg_gzip_decompress(const uint8_t *input, size_t input_length, uint8_t **output, size_t *output_length) {
    z_stream stream;
    uint8_t *buffer = NULL;
    size_t capacity = XG_GZIP_INITIAL_CAPACITY;
    int status;

    if (!input || input_length == 0 || !output || !output_length || input_length > UINT_MAX) return Z_PARAM_ERROR;
    memset(&stream, 0, sizeof(stream));
    stream.next_in = (Bytef *)input;
    stream.avail_in = (uInt)input_length;
    if (inflateInit2(&stream, 15 + 32) != Z_OK) return Z_DATA_ERROR;

    buffer = (uint8_t *)malloc(capacity);
    if (!buffer) {
        inflateEnd(&stream);
        return Z_MEM_ERROR;
    }

    for (;;) {
        if (stream.total_out >= capacity) {
            size_t next_capacity = capacity * 2;
            uint8_t *resized;
            if (next_capacity > XG_GZIP_MAX_OUTPUT) next_capacity = XG_GZIP_MAX_OUTPUT;
            if (next_capacity <= capacity) {
                free(buffer);
                inflateEnd(&stream);
                return Z_MEM_ERROR;
            }
            resized = (uint8_t *)realloc(buffer, next_capacity);
            if (!resized) {
                free(buffer);
                inflateEnd(&stream);
                return Z_MEM_ERROR;
            }
            buffer = resized;
            capacity = next_capacity;
        }
        stream.next_out = buffer + stream.total_out;
        stream.avail_out = (uInt)((capacity - stream.total_out) > UINT_MAX ? UINT_MAX : (capacity - stream.total_out));
        status = inflate(&stream, Z_NO_FLUSH);
        if (status == Z_STREAM_END) break;
        if (status != Z_OK || (stream.avail_in == 0 && stream.avail_out != 0)) {
            free(buffer);
            inflateEnd(&stream);
            return Z_DATA_ERROR;
        }
    }

    inflateEnd(&stream);
    *output = buffer;
    *output_length = stream.total_out;
    return Z_OK;
}

int xg_gzip_compress(const uint8_t *input, size_t input_length, uint8_t **output, size_t *output_length) {
    z_stream stream;
    uint8_t *buffer = NULL;
    uLong bound;
    int status;

    if ((!input && input_length != 0) || !output || !output_length || input_length > UINT_MAX) return Z_PARAM_ERROR;
    memset(&stream, 0, sizeof(stream));
    if (deflateInit2(&stream, Z_DEFAULT_COMPRESSION, Z_DEFLATED, 15 + 16, 8, Z_DEFAULT_STRATEGY) != Z_OK) return Z_DATA_ERROR;

    bound = deflateBound(&stream, (uLong)input_length);
    if (bound == 0 || bound > XG_GZIP_MAX_OUTPUT) {
        deflateEnd(&stream);
        return Z_MEM_ERROR;
    }
    buffer = (uint8_t *)malloc((size_t)bound);
    if (!buffer) {
        deflateEnd(&stream);
        return Z_MEM_ERROR;
    }
    stream.next_in = (Bytef *)input;
    stream.avail_in = (uInt)input_length;
    stream.next_out = buffer;
    stream.avail_out = (uInt)bound;
    status = deflate(&stream, Z_FINISH);
    if (status != Z_STREAM_END) {
        free(buffer);
        deflateEnd(&stream);
        return status == Z_BUF_ERROR ? Z_MEM_ERROR : Z_DATA_ERROR;
    }
    deflateEnd(&stream);
    *output = buffer;
    *output_length = stream.total_out;
    return Z_OK;
}

void xg_gzip_free(void *output) {
    free(output);
}

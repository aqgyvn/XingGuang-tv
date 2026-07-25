#ifndef XG_GZIP_H
#define XG_GZIP_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Returns 0 on success. The caller owns output and releases it with free(). */
int xg_gzip_decompress(const uint8_t *input, size_t input_length, uint8_t **output, size_t *output_length);
int xg_gzip_compress(const uint8_t *input, size_t input_length, uint8_t **output, size_t *output_length);
void xg_gzip_free(void *output);

#ifdef __cplusplus
}
#endif

#endif

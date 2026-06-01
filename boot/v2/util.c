#ifdef __cplusplus
extern "C" {
#endif

__attribute__((used)) void *memcpy(void *dest, const void *src, unsigned n) {
    for(unsigned i = 0; i < n; i++) {
        ((char *)dest)[i] = ((char *)src)[i];
    }

    return dest;
}

#ifdef __cplusplus
}
#endif
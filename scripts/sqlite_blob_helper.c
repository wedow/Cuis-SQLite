#include <string.h>
#include <stdint.h>

/* Copy blob data from sqlite3_column_blob result into a Smalltalk ByteArray.
   src is passed as a pointer-sized integer. */
void sqlite3_copy_blob(unsigned long src_addr, void* dest, unsigned long len) {
    if (src_addr && dest && len > 0) {
        memcpy(dest, (void*)(uintptr_t)src_addr, len);
    }
}

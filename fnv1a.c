#include <inttypes.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#ifdef _WIN32
#  include <fcntl.h>
#  include <io.h>
#endif

int main(void)
{
    uint64_t h = 0xcbf29ce484222325;
    int c;

#ifdef _WIN32
    _setmode(_fileno(stdin), _O_BINARY);
#endif

    while ((c = fgetc(stdin)) != EOF)
    {
	h ^= (unsigned char)c;
	h *= 0x100000001b3ul;
    }

    printf("%" PRIx64 "\n", h);
}


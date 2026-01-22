#include <inttypes.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

int main(void)
{
    uint64_t h = 0xcbf29ce484222325;
    int c;

    while ((c = fgetc(stdin)) != EOF)
    {
	h ^= (unsigned char)c;
	h *= 0x100000001b3ul;
    }

    printf("%" PRIx64 "\n", h);
}


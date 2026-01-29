#include <inttypes.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#ifdef _WIN32
#  include <fcntl.h>
#  include <io.h>
#endif

#define FNV1A_INIT 0xcbf29ce484222325ULL
#define FNV1A_PRIME 0x100000001b3ULL

const char *argv0 = "pfloph";
uint64_t hash = FNV1A_INIT;

unsigned char buf[0x33000];

static void fnv1a(unsigned char *d, size_t n)
{
    if (n) for (size_t i = 0; i < n; ++i)
    {
	hash ^= d[i];
	hash *= FNV1A_PRIME;
    }
    else hash = FNV1A_INIT;
}

static void usage(void)
{
    fprintf(stderr, "usage: %s [-d] [file]\n", argv0);
    exit(EXIT_FAILURE);
}

static int hashfile(FILE *input)
{
    size_t n;
    while ((n = fread(buf, 1, sizeof buf, input)) > 0)
    {
	fnv1a(buf, n);
    }
    return EXIT_SUCCESS;
}

static int hashdisk(FILE *input)
{
    size_t sz = 0;
    size_t n;

    while ((n = fread(buf+sz, 1, (sizeof buf)-sz, input)) > 0)
    {
	sz += n;
	if (sz >= sizeof buf) break;
    }

    unsigned tracks = 0;
    unsigned char *errinfo = 0;

    switch (sz)
    {
	case 174848UL:	tracks = 35; errinfo = 0; break;
	case 175531UL:	tracks = 35; errinfo = buf + 174848UL; break;
	case 196608UL:	tracks = 40; errinfo = 0; break;
	case 197376UL:	tracks = 40; errinfo = buf + 196608UL; break;
	case 205312UL:	tracks = 42; errinfo = 0; break;
	case 206114UL:	tracks = 42; errinfo = buf + 205312UL; break;
	default:	break;
    }

    if (!tracks)
    {
	fputs("Not a supported D64 disk image.\n", stderr);
	return EXIT_FAILURE;
    }

    fprintf(stderr, "Found disk image with %d tracks, %s error info.\n",
	    tracks, errinfo ? "with" : "without");

    unsigned char *base = buf;
    unsigned sectors = 21;
    unsigned sector = 0;
    for (unsigned track = 1; track <= tracks; ++track)
    {
	for (unsigned i = 0; i < sectors; ++i)
	{
	    sector %= sectors;
	    if (errinfo && errinfo[sector] > 1)
	    {
		unsigned char errcode = errinfo[sector] & 0xf;
		fnv1a(&errcode, 1);
	    }
	    else
	    {
		fnv1a(base + 256 * sector, 256);
	    }
	    sector += 11;
	}
	base += 256 * sectors;
	if (errinfo) errinfo += sectors;
	switch (track)
	{
	    case 17: sectors = 19; break;
	    case 24: sectors = 18; break;
	    case 30: sectors = 17; break;
	    default: break;
	}
    }

    return EXIT_SUCCESS;
}

int main(int argc, char **argv)
{
    int diskmode = 0;

    if (argc > 0)
    {
	argv0 = argv[0];
	--argc;
	++argv;
    }

    if (argc > 0 && !strcmp(argv[0], "-d"))
    {
	diskmode = 1;
	--argc;
	++argv;
    }

    if (argc > 1) usage();

    FILE *f = 0;
    FILE *input;
    if (argc > 0)
    {
	if (!(f = input = fopen(argv[0], "rb")))
	{
	    fprintf(stderr, "Cannot open %d for reading.\n", argv[0]);
	    return EXIT_FAILURE;
	}
    }
    else
    {
	input = stdin;
#ifdef _WIN32
	_setmode(_fileno(stdin), _O_BINARY);
#endif
    }

    int rc = EXIT_FAILURE;
    if (diskmode) rc = hashdisk(input);
    else rc = hashfile(input);

    if (f) fclose(f);

    if (rc == EXIT_SUCCESS) printf("%016" PRIx64 "\n", hash);
    return rc;
}


#include <stdio.h>
#include <string.h>

int main(int argc, char **argv)
{
    if (argc != 2) return 1;
    FILE *out = fopen(argv[1], "ab");
    if (!out) return 1;
    unsigned char errinfo[683];
    memset(errinfo, 1, sizeof errinfo);
    errinfo[396] = 5;
    fwrite(errinfo, 1, sizeof errinfo, out);
    fclose(out);
    return 0;
}

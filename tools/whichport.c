#include <stdio.h>
#include <stddef.h>
#include <netdb.h>

int main(int argc, char *argv[])
{
  	struct  servent *se;

	if (argc != 3) {
		printf("%s usage: <protocol> [tcp|udp]\n", argv[0]);
		return 1;
	}

	if ((se = getservbyname(argv[1], argv[2])) == NULL) {
		return 1;
	} else {
		printf("%d\n", ntohs(se->s_port));
	}
    return 0;
}

#include <stdio.h>
#include <stddef.h>
#include <stdlib.h>
#include <netdb.h>

int main(int argc, char *argv[])
{
  	struct  servent *se;
    int     port = atoi(argv[1]);

	if (argc != 3) {
		printf("%s usage: <port> [tcp|udp]\n", argv[0]);
		return 1;
	}

	if ((se = getservbyport(ntohs(port), argv[2])) == NULL) {
		return 1;
	} else {
		printf("%s\n", se->s_name);
	}
    return 0;
}

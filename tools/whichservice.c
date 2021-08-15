/*
   whichservice - Which application protocol is associated with a TCP/UDP port number

   Copyright (C) 2021  Pekka Helenius <pekka.helenius@fjordtek.com>

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 2 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

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

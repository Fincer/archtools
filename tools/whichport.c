/*
   whichport - Which TCP/UDP port number is associated with an application protocol

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

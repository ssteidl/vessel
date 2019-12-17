/*
 *----------------------------------------------------------------------
 * UDP Extension for Tcl 8.4
 *
 * Copyright (c) 1999-2003 by Columbia University; all rights reserved
 * Copyright (c) 2003-2005 Pat Thoyts <patthoyts@users.sourceforge.net>
 *
 * Written by Xiaotao Wu
 * 
 * $Id: udp_tcl.h,v 1.13 2014/05/02 14:41:24 huubeikens Exp $
 *----------------------------------------------------------------------
 */

#ifndef UDP_TCL_H
#define UDP_TCL_H

#include <stdlib.h>

#include <unistd.h>
#include <sys/time.h>
#include <stdint.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <netdb.h>
#include <net/if.h>

#include <stdio.h>
#include <string.h>
#include <limits.h>
#include <errno.h>
#include <sys/types.h>
#include "tcl.h"

#ifdef BUILD_udp
#undef TCL_STORAGE_CLASS
#define TCL_STORAGE_CLASS DLLEXPORT
#endif /* BUILD_udp */

typedef struct UdpState {
  Tcl_Channel       channel;
  int               sock;
  char              remotehost[256]; /* send packets to */
  uint16_t          remoteport;
  char              peerhost[256];   /* receive packets from */
  uint16_t          peerport;
  uint16_t          localport;
  int               doread;
  short				ss_family;		 /* indicator set for ipv4 or ipv6 usage */
  int               multicast;       /* indicator set for multicast add */
  Tcl_Obj          *groupsObj;       /* list of the mcast groups */
} UdpState;


int Udp_Init(Tcl_Interp *interp);
int Udp_SafeInit(Tcl_Interp *interp);

#endif

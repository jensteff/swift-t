
/*
 * hostmap.h
 *
 *  Implements hostmap and rankmap features.
 *
 *  Created on: Feb 4, 2015
 *      Author: wozniak
 */

#ifndef HOSTMAP_H
#define HOSTMAP_H

bool xlb_hostmap_init(bool am_server);
void xlb_hostmap_finalize(void);

const char *xlb_rankmap_lookup(int rank);

#endif

/*
* Copyright 2012 Communications Engineering Lab, KIT
* Copyright 2014 Nuand, LLC
*
* This is free software; you can redistribute it and/or modify
* it under the terms of the GNU General Public License as published by
* the Free Software Foundation; either version 3, or (at your option)
* any later version.
*
* This software is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
* GNU General Public License for more details.
*
* You should have received a copy of the GNU General Public License
* along with this software; see the file COPYING. If not, write to
* the Free Software Foundation, Inc., 51 Franklin Street,
* Boston, MA 02110-1301, USA.
*/

/*
    Find bladeRF devices attached to the host.
*/

/* Simulink includes */
#include <simstruc.h>
#include <mex.h>

/* bladeRF includes */
#include <libbladeRF.h>

/* Entry point to C/C++ */
void mexFunction(int nlhs,mxArray *plhs[],int nrhs,const mxArray *prhs[])
{
    struct bladerf_devinfo *devices;
    int status, i;
    status = bladerf_get_device_list(&devices);

    if (status < 0) {
        if (status == -7)
            mexPrintf("No devices found.\n", devices);
        else
            mexPrintf("Could not communicate with devices. Err=%d\n", status);
        return;
    }

    mexPrintf("Found %d bladeRF device%s:\n", status, (status == 1)  ? "" : "s");

    for (i = 0 ; i < status; i++) {
        mexPrintf("\nDevice Instance %d\n", devices[i].instance);
        mexPrintf("   Serial #: %s\n", &devices[i].serial);
        mexPrintf("   USB Bus: %d\n", devices[i].usb_bus);
        mexPrintf("   USB Addr: %d\n", devices[i].usb_addr);
    }
}

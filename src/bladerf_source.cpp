/*
* Copyright 2012 Communications Engineering Lab, KIT
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
    Interface betweeen bladeRF and Simulink.
*/

#define S_FUNCTION_NAME  bladerf_source
#define S_FUNCTION_LEVEL 2

/* Simulink */
#include "simstruc.h"

/* misc */
#include "utilities.h"
#include <stdint.h>

#include <libbladeRF.h>

/* S-function params */
enum SFcnParamsIndex
{
    DEVICE_INDEX=0,
    SAMPLE_RATE,
    BANDWIDTH,
    FREQUENCY,
    LNAGAIN,
    RXVGA1,
    RXVGA2,
    FRAME_LENGTH,
    USE_FRAMES,
    /* NUM_PARAMS must be the last in this enum to correctly set the number
     * of expected parameters.
     */
    NUM_PARAMS
};

enum PWorkIndex
{
    DEVICE,   /* bladeRF object */
    GAINS,    /* list of possible gain values */

    THREAD,   /* boost thread object for reading samples from dev */
    MUTEX,    /* manages access to SBUF */
    COND_VAR,
    SBUF,     /* sample buffer struct */

    P_WORK_LENGTH
};

enum IWorkIndex
{
    FREQUENCY_PORT_INDEX, /* port index of FREQUENCY signal, 0 if none */
    GAIN_PORT_INDEX,      /* port index of LNAGAIN signal, 0 if none */

    I_WORK_LENGTH
};

enum RWorkIndex
{
    LAST_FREQUENCY, /* holds current FREQUENCY (for port based setting) */
    LAST_GAIN,      /* holds current LNAGAIN (for port based setting) */

    R_WORK_LENGTH
};


/* ======================================================================== */
#if defined(MATLAB_MEX_FILE)
#define MDL_CHECK_PARAMETERS
static void mdlCheckParameters(SimStruct *S)
/* ======================================================================== */
{
    NUMERIC_NOTEMPTY_OR_DIE(S,DEVICE_INDEX);
    NUMERIC_NOTEMPTY_OR_DIE(S,SAMPLE_RATE);
    NUMERIC_NOTEMPTY_OR_DIE(S,FREQUENCY);
    NUMERIC_NOTEMPTY_OR_DIE(S,BANDWIDTH);
    NUMERIC_NOTEMPTY_OR_DIE(S,LNAGAIN);
    NUMERIC_NOTEMPTY_OR_DIE(S,RXVGA1);
    NUMERIC_NOTEMPTY_OR_DIE(S,RXVGA2);
    NUMERIC_NOTEMPTY_OR_DIE(S,FRAME_LENGTH);
    NUMERIC_NOTEMPTY_OR_DIE(S,USE_FRAMES);
}
#endif /* MDL_CHECK_PARAMETERS */


/* ======================================================================== */
#define MDL_INITIAL_SIZES
static void mdlInitializeSizes(SimStruct *S)
/* ======================================================================== */
{
    int_T port;

    /* set number of expected parameters and check for a mismatch. */
    ssSetNumSFcnParams(S, NUM_PARAMS);
    #if defined(MATLAB_MEX_FILE)
    if (ssGetNumSFcnParams(S) == ssGetSFcnParamsCount(S)) {
        mdlCheckParameters(S);
        if (ssGetErrorStatus(S) != NULL) return;
    } else {
         return;
    }
    #endif

    /* sampling */
    ssSetNumSampleTimes(S, PORT_BASED_SAMPLE_TIMES);

    /* Set number of input ports and tunability */
    ssSetSFcnParamTunable(S, DEVICE_INDEX, SS_PRM_NOT_TUNABLE);

    /* set the resulting number of ports */
    if (!ssSetNumInputPorts(S, 0)) return;

    /* Set number of output ports */
    if (!ssSetNumOutputPorts(S, 1)) return;
    /* data port properties */
    port = 0;
    {
        double sample_time = 1/mxGetScalar(ssGetSFcnParam(S, SAMPLE_RATE));

        /* get data port properties */
        const int_T buf_length      = (int_T) (double)mxGetScalar(ssGetSFcnParam(S, FRAME_LENGTH));
        const Frame_T outputsFrames = (       (double)mxGetScalar(ssGetSFcnParam(S, USE_FRAMES))>0.0)? FRAME_YES : FRAME_NO;
        const time_T period         = (time_T)(sample_time * buf_length);

        /* set data port properties */
        ssSetOutputPortMatrixDimensions(S, port, buf_length, 1);
        ssSetOutputPortComplexSignal   (S, port, COMPLEX_YES);
        ssSetOutputPortDataType        (S, port, SS_DOUBLE);
        ssSetOutputPortFrameData       (S, port, outputsFrames);
        ssSetOutputPortSampleTime      (S, port, period);
        ssSetOutputPortOffsetTime      (S, port, 0.0);
    }

    /* Prepare work Vectors */
    ssSetNumPWork(S, P_WORK_LENGTH);
    ssSetNumIWork(S, I_WORK_LENGTH);
    ssSetNumRWork(S, R_WORK_LENGTH);
    ssSetNumModes(S, 0);
    ssSetNumNonsampledZCs(S, 0);

    /* Specify the sim state compliance to be same as a built-in block */
    ssSetSimStateCompliance(S, USE_DEFAULT_SIM_STATE);

    ssSetOptions(S, 0);
}

/* ======================================================================== */
static void mdlInitializeSampleTimes(SimStruct *S)
/* ======================================================================== */
{
    /* PORT_BASED_SAMPLE_TIMES */
}

double lut[4096];
/* ======================================================================== */
#define MDL_START
static void mdlStart(SimStruct *S)
/* ======================================================================== */
{
    int ret = -1;
    char instance[20];
    struct bladerf *dev;
    bladerf_lna_gain brf_lna_gain = BLADERF_LNA_GAIN_UNKNOWN;;
    const uint32_t device_index = (uint32_t)mxGetScalar(ssGetSFcnParam(S, DEVICE_INDEX));
    const uint32_t frequency    = (uint32_t)mxGetScalar(ssGetSFcnParam(S, FREQUENCY ));
    const double   sample_rate  =           mxGetScalar(ssGetSFcnParam(S, SAMPLE_RATE ));
    unsigned int actual_rate;
    const uint32_t lna_gain = (uint32_t)mxGetScalar(ssGetSFcnParam(S, LNAGAIN));
    const uint32_t rxvga1 = (uint32_t)mxGetScalar(ssGetSFcnParam(S, RXVGA1));
    const uint32_t rxvga2 = (uint32_t)mxGetScalar(ssGetSFcnParam(S, RXVGA2));


    /* Set options of this Block */
    ssSetOptions(S, ssGetOptions(S) | SS_OPTION_CALL_TERMINATE_ON_EXIT);

    /* give handle to PWork vector */
    ssSetPWorkValue(S, DEVICE, NULL);

    sprintf(instance, "libusb:instance=%d", device_index);
    /* open bladeRF device */
    ret = bladerf_open(&dev, instance);
    if (ret < 0) {
        ssSetErrorStatusf(S,"Failed to open bladeRF device #%d", device_index);
        return;
    }

    /* give handle to PWork vector */
    ssSetPWorkValue(S, DEVICE, (struct bladerf *)dev);

    /* set gains */

    if (lna_gain == 0)
        brf_lna_gain = BLADERF_LNA_GAIN_BYPASS;
    else if (lna_gain == 3)
        brf_lna_gain = BLADERF_LNA_GAIN_MID;
    else if (lna_gain == 6)
        brf_lna_gain = BLADERF_LNA_GAIN_MAX;

    ret = bladerf_set_lna_gain(dev, brf_lna_gain);
    if (ret < 0) {
        ssSetErrorStatusf(S,"Failed to set RX LNA gain for bladeRF device #%d", device_index);
        return;
    }

    ret = bladerf_set_rxvga1(dev, rxvga1);
    if (ret < 0) {
        ssSetErrorStatusf(S,"Failed to set RXVGA1 for bladeRF device #%d", device_index);
        return;
    }

    ret = bladerf_set_rxvga2(dev, rxvga1);
    if (ret < 0) {
        ssSetErrorStatusf(S,"Failed to set RXVGA2 for bladeRF device #%d", device_index);
        return;
    }

    /* show device name */
    ssPrintf("Using bladeRF device #%d %lf\n", device_index, sample_rate);

    /* set sample rate */
    ret = bladerf_set_sample_rate(dev, BLADERF_MODULE_RX, (uint32_t)sample_rate, &actual_rate);
    if (ret < 0) {
        ssSetErrorStatusf(S,"Failed to set sample rate to %u Sps.\n",(uint32_t)sample_rate);
        return;
    }
    ssPrintf("Sampling at %u Sps.\n", (uint32_t)actual_rate);

    /* set tuning frequency */
    ret = bladerf_set_frequency(dev, BLADERF_MODULE_RX, frequency);
    if (ret < 0) {
        ssSetErrorStatusf(S,"Failed to set center frequency to %u Hz.\n",frequency);
        return;
    }

    ret = bladerf_sync_config(dev, BLADERF_MODULE_RX, BLADERF_FORMAT_SC16_Q11, 64, 16384, 16, 3500);
    if (ret < 0) {
        ssSetErrorStatusf(S,"Failed to initialize sync transfers with error code %d\n", ret);
        return;
    }

    ret = bladerf_enable_module(dev, BLADERF_MODULE_RX, true);
    if (ret < 0) {
        ssSetErrorStatusf(S,"Failed to enable RX with error code %d\n", ret);
        return;
    }
}

/* ======================================================================== */
#define MDL_OUTPUTS
static void mdlOutputs(SimStruct *S, int_T tid)
/* ======================================================================== */
{
    const int_T frame_length = (int_T)(double)mxGetScalar(ssGetSFcnParam(S, FRAME_LENGTH));
    int   ret;

    /* get bladeRF object back from PWork vector */
    struct bladerf *dev = (struct bladerf *)ssGetPWorkValue(S, DEVICE);
    uint16_t *ptr;
    /* output buffer */
    double* out = (double*)ssGetOutputPortSignal(S, 0);

    ptr = (uint16_t *)malloc(frame_length * 2 * sizeof(uint16_t));


    ret = bladerf_sync_rx(dev, ptr, frame_length, NULL, 3500);
    //if (ret < 0)
//        ssSetErrorStatusf(S,"Failed to RX with error code %d\n", ret);
    for (int k = 0; k < frame_length*2; ++k)
        out[k] = ((double)(ptr[k]*1.0f)) / 2048.0f;
    free(ptr);

}

/* ======================================================================== */
static void mdlTerminate(SimStruct *S)
/* ======================================================================== */
{
    int   ret;

    /* check if bladeRF object has been created */
    if (ssGetPWorkValue(S, DEVICE))
    {
        struct bladerf *dev = (struct bladerf *)ssGetPWorkValue(S, DEVICE);

        ret = bladerf_enable_module(dev, BLADERF_MODULE_RX, false);
        if (ret < 0) {
            ssSetErrorStatusf(S,"Could not stop RX module with error code %d\n", ret);
        }
        bladerf_close(dev);
    }

}

#ifdef  MATLAB_MEX_FILE    /* Is this file being compiled as a MEX-file? */
#include "simulink.c"      /* MEX-file interface mechanism */
#else
#include "cg_sfun.h"       /* Code generation registration function */
#endif

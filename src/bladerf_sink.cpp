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

#define S_FUNCTION_NAME  bladerf_sink
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
    TXVGA1,
    TXVGA2,
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
    NUMERIC_NOTEMPTY_OR_DIE(S,TXVGA1);
    NUMERIC_NOTEMPTY_OR_DIE(S,TXVGA2);
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
    if (!ssSetNumInputPorts(S, 1)) return;

    port = 0;
    {
        const Frame_T inputsFrames = (       (double)mxGetScalar(ssGetSFcnParam(S, USE_FRAMES))>0.0)? FRAME_YES : FRAME_NO;
        double sample_time = 1/mxGetScalar(ssGetSFcnParam(S, SAMPLE_RATE));
        const int_T buf_length      = (int_T) (double)mxGetScalar(ssGetSFcnParam(S, FRAME_LENGTH));
        const time_T period         = (time_T)(sample_time * buf_length);

        ssSetInputPortMatrixDimensions(S, port, buf_length, 1);
        ssSetInputPortComplexSignal   (S, port, COMPLEX_YES);
        ssSetInputPortDataType        (S, port,  SS_DOUBLE);
        ssSetInputPortFrameData       (S, port, inputsFrames);
        ssSetInputPortDirectFeedThrough(S, port, 1);
        ssSetInputPortSampleTime(S, port, period);
        ssSetInputPortOffsetTime(S, port, 0.0);
    }

    /* Set number of output ports */
    if (!ssSetNumOutputPorts(S, 0)) return;
    /* data port properties */
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
    const uint32_t txvga1 = (uint32_t)mxGetScalar(ssGetSFcnParam(S, TXVGA1));
    const uint32_t txvga2 = (uint32_t)mxGetScalar(ssGetSFcnParam(S, TXVGA2));
    const int_T buf_length      = (int_T) (double)mxGetScalar(ssGetSFcnParam(S, FRAME_LENGTH));


    /* Set options of this Block */
    ssSetOptions(S, ssGetOptions(S) | SS_OPTION_CALL_TERMINATE_ON_EXIT);

    /* give handle to PWork vector */
    ssSetPWorkValue(S, DEVICE, NULL);

    sprintf(instance, "*:instance=%d", device_index);
    /* open bladeRF device */
    ret = bladerf_open(&dev, instance);
    if (ret < 0) {
        ssSetErrorStatusf(S,"Failed to open bladeRF device #%d", device_index);
        return;
    }

    /* give handle to PWork vector */
    ssSetPWorkValue(S, DEVICE, (struct bladerf *)dev);

    /* set gains */
    ret = bladerf_set_txvga1(dev, txvga1);
    if (ret < 0) {
        ssSetErrorStatusf(S,"Failed to set TXVGA1 for bladeRF device #%d", device_index);
        return;
    }

    ret = bladerf_set_txvga2(dev, txvga1);
    if (ret < 0) {
        ssSetErrorStatusf(S,"Failed to set TXVGA2 for bladeRF device #%d", device_index);
        return;
    }

    /* show device name */
    ssPrintf("Using bladeRF device #%d %lf\n", device_index, sample_rate);

    /* set sample rate */
    ret = bladerf_set_sample_rate(dev, BLADERF_MODULE_TX, (uint32_t)sample_rate, &actual_rate);
    if (ret < 0) {
        ssSetErrorStatusf(S,"Failed to set sample rate to %u Sps.\n",(uint32_t)sample_rate);
        return;
    }
    ssPrintf("Sampling at %u Sps.\n", (uint32_t)actual_rate);

    /* set tuning frequency */
    ret = bladerf_set_frequency(dev, BLADERF_MODULE_TX, frequency);
    if (ret < 0) {
        ssSetErrorStatusf(S,"Failed to set center frequency to %u Hz.\n",frequency);
        return;
    }

    ret = bladerf_sync_config(dev, BLADERF_MODULE_TX, BLADERF_FORMAT_SC16_Q11, 128, 4096, 8, 500);
    if (ret < 0) {
        ssSetErrorStatusf(S,"Failed to initialize sync transfers with error code %d\n", ret);
        return;
    }

    ret = bladerf_set_stream_timeout(dev, BLADERF_MODULE_TX, 500);
    if (ret < 0) {
        ssSetErrorStatusf(S,"Failed to set TX stream timeout with error code %d\n", ret);
        return;
    }

    ret = bladerf_enable_module(dev, BLADERF_MODULE_TX, true);
    if (ret < 0) {
        ssSetErrorStatusf(S,"Failed to enable TX with error code %d\n", ret);
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
    double* out = (double*)ssGetInputPortSignalPtrs(S, 0);

    ptr = (uint16_t *)malloc(frame_length * 2 * sizeof(uint16_t));
    ret = bladerf_sync_tx(dev, ptr, frame_length, NULL, 500);
//    if (ret < 0)
//      ssSetErrorStatusf(S,"Failed to TX with error code %d\n", ret);
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

        ret = bladerf_enable_module(dev, BLADERF_MODULE_TX, false);
        if (ret < 0) {
            ssSetErrorStatusf(S,"Could not stop TX module with error code %d\n", ret);
        }
        bladerf_close(dev);
    }

}

#ifdef  MATLAB_MEX_FILE    /* Is this file being compiled as a MEX-file? */
#include "simulink.c"      /* MEX-file interface mechanism */
#else
#include "cg_sfun.h"       /* Code generation registration function */
#endif

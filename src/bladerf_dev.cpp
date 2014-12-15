/*
 * Copyright 2012 Communications Engineering Lab, KIT
 * Copyright 2014 Nuand LLC
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
   Interface betweeen bladeRF and MATLAB.
 */

/* Simulink */
#include "mex.h"

/* misc */
#include "utilities.h"
#include <string.h>

/* bladeRF includes */
#include <libbladeRF.h>

/* interface */
#define DEVICE_INDEX  prhs[0]
#define DEVICE_MODE   prhs[1]
#define SAMPLE_RATE   prhs[2]
#define BANDWIDTH     prhs[3]
#define FREQUENCY     prhs[4]
#define GAIN          prhs[5]
#define BUF_LENGTH    prhs[6]
#define TX_DATA       prhs[6]
#define DEVICE_HANDLE plhs[0]
#define RECEIVE_DATA  plhs[0]
#define num_inputs    7
#define num_outputs   1

/* defines */
#define NUM_SUPPORT   20

/* global variables */
struct bladerf *_devices [NUM_SUPPORT];
#define MODE_RX     1
#define MODE_TX     2
int _device_modes      [NUM_SUPPORT];
int _sample_rates      [NUM_SUPPORT];
uint32_t _frequencies  [NUM_SUPPORT];
int _bandwidths        [NUM_SUPPORT];
int _lnagains          [NUM_SUPPORT];
int _rxvga1s           [NUM_SUPPORT];
int _rxvga2s           [NUM_SUPPORT];
int _txvga1s           [NUM_SUPPORT];
int _txvga2s           [NUM_SUPPORT];
int _buf_lengths       [NUM_SUPPORT];

void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[]) {

    int ret;
    char errmsg[250];
    char buf[50];

    /* close device */
    if (nlhs == 0 && nrhs == 1) {

        /* check input */
        CHECK_DEVICE_INDEX(DEVICE_INDEX);

        /* get device index from input */
        int device_index = (int)mxGetScalar(DEVICE_INDEX);

        /* check if device is used */
        if (_devices[device_index]) {
            if (_device_modes[device_index] & MODE_RX) {
                ret = bladerf_enable_module(_devices[device_index], BLADERF_MODULE_RX, false);
                if (ret < 0) {
                    sprintf(errmsg, "Failed to shutdown RX for bladeRF device #%d.\n", device_index); mexErrMsgTxt(errmsg);
                    mexErrMsgTxt(errmsg);
                    return;
                }
                mexPrintf("Disabled bladeRF RX.\n");
            }

            if (_device_modes[device_index] & MODE_TX) {
                ret = bladerf_enable_module(_devices[device_index], BLADERF_MODULE_TX, false);
                if (ret < 0) {
                    sprintf(errmsg, "Failed to shutdown TX for bladeRF device #%d.\n", device_index); mexErrMsgTxt(errmsg);
                    mexErrMsgTxt(errmsg);
                    return;
                }
                mexPrintf("Disabled bladeRF TX.\n");
            }

            /* close device */
            bladerf_close(_devices[device_index]);

            _devices[device_index] = NULL;

            /* reset settings */
            _sample_rates[device_index] = -1;
            _bandwidths  [device_index] = -1;
            _frequencies [device_index] = -1;
            _lnagains    [device_index] = -1000;
            _rxvga1s     [device_index] = -1000;
            _rxvga2s     [device_index] = -1000;
            _buf_lengths [device_index] = -1;

            mexPrintf("Closed bladeRF device #%d.\n",device_index);
        }
        /* device is not used */
        else {
            sprintf(errmsg,"bladeRF device #%d is not in use.\n",device_index); mexErrMsgTxt(errmsg);
        }
    }
    /* open device */
    else if (nrhs == 1 && nlhs == 1) {
        /* initialize device handle */
        DEVICE_HANDLE = mxCreateDoubleMatrix(1, 1, mxREAL);
        *mxGetPr(DEVICE_HANDLE) = -1;

        /* check input */
        CHECK_DEVICE_INDEX(DEVICE_INDEX);

        /* get device index from input */
        int device_index = (int)mxGetScalar(DEVICE_INDEX);

        /* check if device is used */
        if (_devices[device_index]) {
            sprintf(errmsg,"bladeRF device #%d is already in use.\n",device_index); mexErrMsgTxt(errmsg);
        }
        /* device is not used */
        else {

            /* open bladeRF device */
            sprintf(buf, "libusb:instance=%d", device_index);
            ret = bladerf_open(&_devices[device_index], buf);
            if (ret < 0) {
                sprintf(errmsg," Failed to use bladeRF device #%d.\n",device_index); mexErrMsgTxt(errmsg);
                return;
            }

            /* configu RX configuration buffers */
            ret = bladerf_sync_config(_devices[device_index], BLADERF_MODULE_RX, BLADERF_FORMAT_SC16_Q11, 64, 16384, 16, 0);
            if (ret < 0) {
                sprintf(errmsg, "Failed to initialize sync transfers with error code %d\n", ret); mexErrMsgTxt(errmsg);
                return;
            }

            /* configu TX configuration buffers */
            ret = bladerf_sync_config(_devices[device_index], BLADERF_MODULE_TX, BLADERF_FORMAT_SC16_Q11, 64, 1024, 16, 0);
            if (ret < 0) {
                sprintf(errmsg, "Failed to initialize sync transfers with error code %d\n", ret); mexErrMsgTxt(errmsg);
                return;
            }

            *mxGetPr(DEVICE_HANDLE) = device_index;

            /* reset settings */
            _device_modes[device_index] = 0;
            _sample_rates[device_index] = -1;
            _frequencies [device_index] = -1;
            _buf_lengths [device_index] = -1;

            mexPrintf("Using bladeRF device #%d\n",device_index);
        }
    }
    else if (nrhs == num_inputs && nlhs == num_outputs) {

        int rx;
        char mode[10];
        bladerf_module mod;

        /* check input */
        CHECK_DEVICE_INDEX(DEVICE_INDEX);
        CHECK_BANDWIDTH   (BANDWIDTH   );
        CHECK_SAMPLE_RATE (SAMPLE_RATE );
        CHECK_FREQUENCY   (FREQUENCY   );

        rx = 1;
        if (mxGetString(DEVICE_MODE, (char *)&mode, 3)) {
            rx = 1;
            CHECK_BUF_LENGTH  (BUF_LENGTH  );
        } else {
            if (!strcmp(mode, "TX"))
                rx = 0;
        }

        mod = BLADERF_MODULE_RX;
        if (!rx)
            mod = BLADERF_MODULE_TX;

        /* get device index from input */
        int device_index = (int)mxGetScalar(DEVICE_INDEX);

        struct bladerf *_device = _devices[device_index];

        /* check if device is already in use */
        if (!_devices[device_index]) {
            sprintf(errmsg,"bladeRF device #%d is not initialized.\n",device_index); mexErrMsgTxt(errmsg);
        }

        /* set sample rate */
        uint32_t sample_rate = (int)mxGetScalar(SAMPLE_RATE);
        uint32_t actual;
        if (sample_rate != _sample_rates[device_index]) {
            ret = bladerf_set_sample_rate(_device, mod, (uint32_t)sample_rate, &actual);
            if (ret < 0) {
                sprintf(errmsg,"Failed to set sample rate to %u Sps.\n",sample_rate); mexErrMsgTxt(errmsg);
            } else {
                if (sample_rate != actual) {
                    mexPrintf("Adjusting sample rate to %d\n", actual);
                }
            }
            _sample_rates[device_index]=sample_rate;
        }

        /* set bandwidth */
        uint32_t bandwidth = (int)mxGetScalar(BANDWIDTH);
        uint32_t actualbw;
        if (bandwidth != _bandwidths[device_index]) {
            ret = bladerf_set_bandwidth(_device, mod, bandwidth, &actualbw);
            if (ret < 0) {
                sprintf(errmsg,"Failed to set bandwidth to %u Hz.\n", bandwidth); mexErrMsgTxt(errmsg);
            }
            if (bandwidth != actualbw) {
                mexPrintf("Actual bandwidth set to %u Hz.\n", actualbw);
            }

            _bandwidths[device_index] = bandwidth;
        }

        /* set tuning frequency */
        uint32_t frequency = (uint32_t)mxGetScalar(FREQUENCY);
        if (frequency != _frequencies[device_index]) {

            ret = bladerf_set_frequency(_device, mod, (uint32_t)frequency);
            if (ret < 0) {
                sprintf(errmsg,"Failed to set center frequency to %u Hz.\n",frequency); mexErrMsgTxt(errmsg);
            }

            _frequencies[device_index] = frequency;
        }

        /* set gains */
        double *gains = mxGetPr(GAIN);
        if (mxGetN(GAIN) == 1) {
            int gain = (int)gains[0];
            ret = bladerf_set_gain(_device, rx ? BLADERF_MODULE_RX : BLADERF_MODULE_TX, gain);
            if (ret < 0) {
                sprintf(errmsg,"Failed to set unified gain for %s to %u db.\n", gain, rx ? "RX" : "TX"); mexErrMsgTxt(errmsg);
            }
        } else if (rx && mxGetN(GAIN) == 3) {
            /* set LNA gain */
            int lnagain = (int)gains[0];
            mexPrintf("LNA gain = %d, RXVGA1 = %d, RXVGA2 = %d\n", (int)gains[0], (int)gains[1], (int)gains[2]);
            bladerf_lna_gain brf_lna = BLADERF_LNA_GAIN_UNKNOWN;
            if (lnagain != _lnagains[device_index]) {
                _lnagains[device_index] = lnagain;
                if (lnagain >= 6)
                    brf_lna = BLADERF_LNA_GAIN_MAX;
                else if (lnagain >= 3)
                    brf_lna = BLADERF_LNA_GAIN_MID;
                else if (lnagain >= 0)
                    brf_lna = BLADERF_LNA_GAIN_BYPASS;
                ret = bladerf_set_lna_gain(_device, brf_lna);
                if (ret < 0) {
                    sprintf(errmsg,"Failed to set LNA gain to %d dB.\n", lnagain); mexErrMsgTxt(errmsg);
                }
            }

            /* set RXVGA1 gain */
            int rxvga1 = (int)gains[1];
            if (rxvga1 != _rxvga1s[device_index]) {
                _rxvga1s[device_index] = rxvga1;
                ret = bladerf_set_rxvga1(_device, rxvga1);
                if (ret < 0) {
                    sprintf(errmsg,"Failed to set RXVGA1 to %u db.\n", rxvga1); mexErrMsgTxt(errmsg);
                }
            }

            /* set RXVGA2 gain */
            int rxvga2 = (int)gains[2];
            if (rxvga2 != _rxvga1s[device_index]) {
                _rxvga2s[device_index] = rxvga1;
                ret = bladerf_set_rxvga2(_device, rxvga2);
                if (ret < 0) {
                    sprintf(errmsg,"Failed to set RXVGA2 to %u db.\n", rxvga2); mexErrMsgTxt(errmsg);
                }
            }
        } else if (!rx && mxGetN(GAIN) == 2) {
            /* set TXVGA1 */
            int txvga1 = (int)gains[0];
            if (txvga1 != _txvga1s[device_index]) {
                _txvga1s[device_index] = txvga1;
                ret = bladerf_set_txvga1(_device, txvga1);
                if (ret < 0) {
                    sprintf(errmsg,"Failed to set TXVGA1 to %u db.\n", txvga1); mexErrMsgTxt(errmsg);
                }
            }

            /* set TXVGA2 */
            int txvga2 = (int)gains[1];
            if (txvga2 != _txvga1s[device_index]) {
                _txvga2s[device_index] = txvga1;
                ret = bladerf_set_txvga2(_device, txvga2);
                if (ret < 0) {
                    sprintf(errmsg,"Failed to set TXVGA2 to %u db.\n", txvga2); mexErrMsgTxt(errmsg);
                }
            }
        }

        if (rx) {
            /* enable RX module if it isn't already */
            if (!(_device_modes[device_index] & MODE_RX)) {
                _device_modes[device_index] |= MODE_RX;
                ret = bladerf_enable_module(_devices[device_index], BLADERF_MODULE_RX, true);
                if (ret < 0) {
                    sprintf(errmsg, "Failed to initialize RX module with error code %d\n", ret); mexErrMsgTxt(errmsg);
                    return;
                }
            }
            /* set buffer length */
            int buf_length = (int)mxGetScalar(BUF_LENGTH);
            if (buf_length != _buf_lengths[device_index]) {
                _buf_lengths[device_index] = buf_length;
            }

            /* allocate buffer memory */
            int16_t *buffer = (int16_t*) malloc(buf_length * 2 * sizeof(int16_t));

            int n_read;
            ret = bladerf_sync_rx(_device, buffer, buf_length, NULL, 0);

            if (ret < 0) {
                sprintf(errmsg,"Failed to read from device.\n"); mexErrMsgTxt(errmsg);
            }

            /* create output data */
            RECEIVE_DATA = mxCreateDoubleMatrix(buf_length, 1, mxCOMPLEX);
            double *outr = (double*)mxGetPr(RECEIVE_DATA);
            double *outi = (double*)mxGetPi(RECEIVE_DATA);

            int k;
            /* pass buffer values to output */
            for (k=0; k<buf_length; k++) {
                /* scaling */
                outr[k] = ((double)(buffer[ (k<<1)   ]))/2048.0f;
                outi[k] = ((double)(buffer[((k<<1)+1)]))/2048.0f;
            }

            /* free the allocated buffer memory */
            free((void*)buffer);
        } else {
            /* enable TX module if it isn't already */
            if (!(_device_modes[device_index] & MODE_TX)) {
                _device_modes[device_index] |= MODE_TX;
                ret = bladerf_enable_module(_devices[device_index], BLADERF_MODULE_TX, true);
                if (ret < 0) {
                    sprintf(errmsg, "Failed to initialize RX module with error code %d\n", ret); mexErrMsgTxt(errmsg);
                    return;
                }
            }

            int len = mxGetN(TX_DATA);

            int16_t *buffer = (int16_t*) malloc(len * 2 * sizeof(int16_t));

            /* Get pointers to data */
            double *outr = (double*)mxGetPr(TX_DATA);
            double *outi = (double*)mxGetPi(TX_DATA);

            int k;
            /* convert from double to int */
            for (k=0; k<len; k++) {
                /* scaling */
                buffer[ (k<<1)   ] = outr[ k ] * 2048;
                buffer[ (k<<1)+1 ] = outi[ k ] * 2048;
            }

            /* create return data */
            RECEIVE_DATA = mxCreateDoubleMatrix(1, 1, mxREAL);
            double *ret = (double *)mxGetPr(RECEIVE_DATA);

            *ret = bladerf_sync_tx(_device, buffer, len, NULL, 0);
            free((void *)buffer);
        }
    }
    else {

        /* Usage */
        mexPrintf("\nUsage:"
                "\n\n"
                "     \t# Initialize bladeRF device:\n\n"
                "     \t\thandle = bladerf_dev(index)\n\n"
                "     \t     handle - The returned handle used for addressing the initialized bladeRF device.\n"
                "     \t      index - The device index (e.g. 0).\n\n\n"
                "     \t# Close bladeRF device:\n\n"
                "     \t\tbladerf_dev(handle)\n\n"
                "     \t     handle - The returned handle used for the initialized bladeRF device.\n\n\n"
                "     \t# Receive IQ-samples from bladeRF device:\n\n"
                "     \t\trxdata = bladerf_dev(handle,'RX',samplerate,bandwidth,frequency,gains,buf_length)\n\n\n"
                "     \t     rxdata - The received IQ-samples.\n"
                "     \t     handle - The returned handle used for the initialized bladeRF device.\n"
                "     \t samplerate - The sampling rate of the device (200kHz - 40MHz) (e.g. 1e6 for 1 MHz bandwidth).\n"
                "     \t  frequency - The center frequency of the tuner (60kHz - 3.8GHz) (e.g. 100e6 for 100 MHz).\n"
                "     \t      gains -  A scalar unified gain from 0db to 90dB (e.g. 10 for 10 dB of RX gain).\n"
                "     \t            ` Alternate mode: 3 index array specifying LNA, RXVGA1, and RXVGA2 gains expressed in dB (e.g. [ 3 10 0 ] ).\n"
                "     \t buf_length - The number of samples in the receive buffer (e.g. 1000).\n\n\n"

                "     \t# Transmit IQ-samples to bladeRF device:\n\n"
                "     \t\tret = bladerf_dev(handle,'TX',samplerate,bandwidth,frequency,gains,txdata)\n\n\n"
                "     \t        ret - Return status of transmit operation. 0 on success.\n"
                "     \t     handle - The returned handle used for the initialized bladeRF device.\n"
                "     \t samplerate - The sampling rate of the device (200kHz - 40MHz) (e.g. 1e6 for 1 MHz bandwidth).\n"
                "     \t  frequency - The center frequency of the tuner (60kHz - 3.8GHz) (e.g. 100e6 for 100 MHz).\n"
                "     \t      gains - A scalar unified gain from -35dB to 25dB (e.g. 5 for 5dB of TX gain).\n"
                "     \t            ` Alternate mode: 2 index array specifying TXVGA1, and TXVGA2 gains expressed in dB (e.g. [ -4 10 ] ).\n"
                "     \t     txdata - The transmitted IQ-samples.\n\n");

        return;
    }
}

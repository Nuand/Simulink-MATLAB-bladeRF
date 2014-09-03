%     	# Initialize bladeRF device:
%
%     		handle = bladerf_dev(index)
%
%     	     handle - The returned handle used for addressing the initialized bladeRF device.
%     	      index - The device index (e.g. 0).
%
%
%     	# Close bladeRF device:
%
%     		bladerf_dev(handle)
%
%     	     handle - The returned handle used for the initialized bladeRF device.
%
%
%     	# Receive IQ-samples from bladeRF device:
%
%     		rxdata = bladerf_dev(handle,'RX',samplerate,bandwidth,frequency,gains,buf_length)
%
%
%     	     rxdata - The received IQ-samples.
%     	     handle - The returned handle used for the initialized bladeRF device.
%     	 samplerate - The sampling rate of the device (200kHz - 40MHz) (e.g. 1e6 for 1 MHz bandwidth).
%     	  frequency - The center frequency of the tuner (60kHz - 3.8GHz) (e.g. 100e6 for 100 MHz).
%             gains - A scalar unified gain from 0db to 90dB (e.g. 10 for 10 dB of RX gain).
%                   ` Alternate mode: 3 index array specifying LNA, RXVGA1, and RXVGA2 gains expressed in dB (e.g. [ 3 10 0 ] ).
%     	 buf_length - The number of samples in the receive buffer (e.g. 1000).
%
%
%     	# Transmit IQ-samples to bladeRF device:
%
%     		ret = bladerf_dev(handle,'TX',samplerate,bandwidth,frequency,gains,txdata)
%
%
%     	        ret - Return status of transmit operation. 0 on success.
%     	     handle - The returned handle used for the initialized bladeRF device.
%     	 samplerate - The sampling rate of the device (200kHz - 40MHz) (e.g. 1e6 for 1 MHz bandwidth).
%     	  frequency - The center frequency of the tuner (60kHz - 3.8GHz) (e.g. 100e6 for 100 MHz).
%             gains - A scalar unified gain from -35dB to 25dB (e.g. 5 for 5dB of TX gain).
%                   ` Alternate mode: 2 index array specifying TXVGA1, and TXVGA2 gains expressed in dB (e.g. [ -4 10 ] ).
%     	     txdata - The transmitted IQ-samples.
%

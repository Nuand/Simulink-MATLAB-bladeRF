%% Setup device
dev = bladeRF();

Fc = 915e6;
Fs = 5e6;

num_seconds = 3;
Ftone = 750e3;
omega = 2 * pi * Ftone;
t = 0 : 1/Fs : num_seconds;

sig = 0.5 .* exp(1j * omega * t);

dev.tx.frequency  = Fc;
dev.tx.samplerate = Fs;
dev.tx.bandwidth  = 1.5e6;
dev.tx.vga2 = 0;
dev.tx.vga1 = -20;

dev.tx.config.num_buffers = 64;
dev.tx.config.buffer_size = 4096;
dev.tx.config.num_transfers = 16;

fprintf('Running with the following settings:\n');
disp(dev.tx)
disp(dev.tx.config)


% Transmit the entire signal as a "burst" with some zeros padded on either
% end of it.
dev.tx.start();

%% Send samples as a single burst
dev.transmit(sig, 2 * num_seconds, 0, true, true);


%% Send samples 3 times, but as a single burst split across 3 calls
% end_i = round(length(sig) / 3);
% dev.transmit(sig(1:end_i), 2 * num_seconds, 0, true, false);
%
% start_i = end_i + 1;
% end_i = round(length(sig) * 2 / 3);
% dev.transmit(sig(start_i:end_i), 2 * num_seconds, 0, false, false);
%
% start_i = end_i + 1;
% dev.transmit(sig(start_i:end), 2 * num_seconds, 0, false, true);


%% Send samples via a stream-like use case.
% end_i = round(length(sig) / 3);
% dev.transmit(sig(1:end_i));
%
% start_i = end_i + 1;
% end_i = round(length(sig) * 2 / 3);
% dev.transmit(sig(start_i:end_i));
%
% start_i = end_i + 1;
% dev.transmit(sig(start_i:end));

%% Shutdown and cleanup
dev.tx.stop();
clear dev Fs Fc Ftone num_seconds t omega sig start_i end_i

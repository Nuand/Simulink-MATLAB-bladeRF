dev = bladeRF();

Fc = 915e6;
Fs = 5e6;

% Produce 5s of a 250 kHz tone
num_seconds = 5;
Ftone = 250e3;
omega = 2 * pi * Ftone;
t = [0:1/Fs:num_seconds];

sig = 0.5 .* exp(1j * omega * t);

dev.tx.frequency  = Fc;
dev.tx.samplerate = Fs;
dev.tx.bandwidth  = 1.5e6;
dev.tx.vga2 = 0;
dev.tx.vga1 = -20;

fprintf('Running with the following settings:\n');
dev.tx
dev.tx.config

% Transmit the entire signal as a "burst" with some zeros padded on either
% end of it.
dev.tx.start();

dev.transmit(sig, 2 * num_seconds, 0, 1, 1);

%dev.transmit(sig);
%dev.transmit(sig);

dev.tx.stop();

clear dev;
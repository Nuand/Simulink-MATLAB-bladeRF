%
% Copyright 2010 Communications Engineering Lab, KIT
% Copyright 2014 Nuand, LLC
%
% This is free software; you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation; either version 3, or (at your option)
% any later version.
%
% This software is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
% GNU General Public License for more details.
%
% You should have received a copy of the GNU General Public License
% along with this software; see the file COPYING. If not, write to
% the Free Software Foundation, Inc., 51 Franklin Street,
% Boston, MA 02110-1301, USA.
%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% make script for Simulink-bladeRF
% use "make -v" to get a verbose output
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function make(varargin)

bladerfinstall = fullfile(pwd,'deps','bladerf');
installed = 1;
try
    bladerfinstall = winqueryreg('HKEY_LOCAL_MACHINE', 'SOFTWARE\Nuand LLC', 'Path');
catch
    installed = 0;
end

if (strcmp(computer('arch'),'win64'))
    arch = 'x64';
else
    arch = 'x86';
end
BLADERF_BIN_DIR = fullfile(pwd,'bin');
BLADERF_BLOCKSET_DIR = fullfile(pwd,'blockset');
if installed
    disp('Copying files')
    copyfile(sprintf('%s/%s/*.dll', bladerfinstall, arch), BLADERF_BIN_DIR)
end
if ispc
    % this should point to the directory of bladeRF.h
    BLADERF_INC_DIR = fullfile(bladerfinstall,'include');
    % this should point to the directory of bladeRF.lib
    BLADERF_LIB_DIR = fullfile(bladerfinstall,'lib',arch);

    % make sure the other required DLLS are in your PATH
    % (e.g. place them in the bin directory)

    options = { ...
        ['-I' bladerfinstall]; ...
        ['-I' BLADERF_INC_DIR]; ...
        ['-L' BLADERF_LIB_DIR]; ...
        ['-l' 'bladeRF']; ...
    };
elseif isunix
    options = { ...
        ['-l' 'bladeRF']
    };
    options_pthread = { ...
        ['-l' 'pthread'] ...
    };
else
    error('Platform not supported')
end

% create bin order if not exist
if (~exist(BLADERF_BIN_DIR,'dir'))
    mkdir(BLADERF_BIN_DIR);
end

% add command line args if exist
if ~isempty(varargin)
    options = [options; char(varargin)];
end

% Set path hint

% compile sink, source, find_devices, dev
fprintf('\nCompiling bladerf_source.cpp ... ');
mex(options{:},'-outdir',BLADERF_BIN_DIR,'src/bladerf_source.cpp')
fprintf('Done.\n');

fprintf('\nCompiling bladerf_sink.cpp ... ');
mex(options{:},'-outdir',BLADERF_BIN_DIR,'src/bladerf_sink.cpp')
fprintf('Done.\n');

fprintf('\nCompiling bladerf_find_devices.cpp ... ');
mex(options{:},'-outdir',BLADERF_BIN_DIR,'src/bladerf_find_devices.cpp')
fprintf('Done.\n');

fprintf('\nCompiling bladerf_dev.cpp ... ');
mex(options{:},'-outdir',BLADERF_BIN_DIR,'src/bladerf_dev.cpp')
fprintf('Done.\n');

% copy help file
copyfile(fullfile(pwd,'src','bladerf_dev.m'),fullfile(BLADERF_BIN_DIR,'bladerf_dev.m'));


% Set path hint
fprintf('\nBuild successful.\n\nSet path to:\n -> %s\n -> %s\n',BLADERF_BIN_DIR,BLADERF_BLOCKSET_DIR);

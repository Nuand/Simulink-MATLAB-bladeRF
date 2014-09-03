function blkStruct = slblocks
% Returns information about the bladeRF device
% to the Simulink library browser.
%
% @version:		1.0
% @author:		Robert Ghilduta <robert.ghilduta@nuand.com>, Michael Schwall <michael.schwall@kit.edu>
% @copyright:		Nuand LLC, http://nuand.com/ Communications Engineering Lab, http://www.cel.kit.edu
% @license:		GNU General Public License, Version 3

% Information for the "Blocksets and Toolboxes" subsystem (findblib)
blkStruct.Name = sprintf('Nuand bladeRF');
blkStruct.OpenFcn = 'bladerf';
blkStruct.MaskDisplay = 'disp(''bladeRF'')';

% Information for the "Simulink Library Browser"
Browser(1).Library = 'bladerf';
Browser(1).Name    = 'Nuand bladeRF Software Defined Radio';
Browser(1).IsFlat  = 0;

blkStruct.Browser = Browser;
clear Browser;

blkStruct.ModelUpdaterMethods.fhUpdateModel = @UpdateSimulinkBlocksHelper;

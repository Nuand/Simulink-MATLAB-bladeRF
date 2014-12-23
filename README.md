Simulink-MATLAB-bladeRF
================

The Simulink-MATLAB-bladeRF project adds Simulink and MATLAB support to the [bladeRF](https://nuand.com/bladeRF). bladeRF is a Software Defined Radio (SDR) platform designed to enable a community of hobbyists, and professionals to explore and experiment with the multidisciplinary facets of RF communication. By providing source code, thorough documentation, easy to grasp tutorials, and a place for open discussion modern radio systems will be demystified by covering everything from the RF, analog, and digital hardware design to the firmware running on the ARM MCU and FPGA to Linux kernel device drivers.

Compiled Windows Binaries Installer
-----------------------------------

[A Windows installer](https://nuand.com/downloads/bladerf_win_installer.exe) for drivers and libbladeRF with MATLAB and Simulink support can be downloaded directly from the Nuand web server. The installer installs bladeRF support for MATLAB versions R2012A through R2014B.

Requirements
------------

- MATLAB/Simulink (R2012a or newer) and *MEX* compatible [compiler](http://www.mathworks.de/support/compilers)

- *bladeRF* library from the [bladeRF](https://github.com/Nuand/bladeRF "bladeRF project page")

Build/Install instructions for Linux
------------------------------------

1. Get, build and install the *bladeRF* library. See the [bladeRF Wiki](https://github.com/Nuand/bladeRF/wiki/) for instructions.

2. Plug in your device and run the included test application

    $ bladeRF-cli -p

        Backend:        libusb
        Serial:         yourSERIALnumber387cc22
        USB Bus:        1
        USB Address:    9

3. Get the Simulink-MATLAB-bladeRF source from the [GitHub](https://github.com/Nuand/Simulink-MATLAB-bladeRF) project page

    $ git clone git://github.com/Nuand/Simulink-MATLAB-bladeRF.git

4. Run MATLAB, switch to your Simulink-MATLAB-bladeRF directory and start the build process

    >> make.m

5. Add the *bin* and the *blockset* directory to the MATLAB path environment.

6. You will now find a new Toolbox named *Nuand bladeRF Software Defined Radio* in the *Simulink Library Browser*. Additionally, a simple spectrum scope model is located in the directory *demo*.


Build/Install instructions for Microsoft Windows
------------------------------------------------

1. Get and build the *bladeRF* library. See the [bladeRF Wiki](https://github.com/Nuand/bladeRF) for instructions or get [pre-built binaries](https://nuand.com/downloads/bladerf_win_installer.exe).

2. Plug in your device, abort the automated search for drivers.

3. Download and install the Windows binaries from [Nuand's site](https://nuand.com/downloads/bladerf_win_installer.exe). This will install the necessary drivers, utilities and libraries needed to build and run Simulink bladeRF.

4. Test the *bladeRF* library with the included test application

C:\Users\Robert>bladeRF-cli -p

    Backend:        libusb
    Serial:         yourSERIALnumber387cc22
    USB Bus:        1
    USB Address:    9

6. Get the Simulink-MATLAB-bladeRF source from the [GitHub](https://github.com/Simulink-MATLAB-bladeRF) project page

    $ git clone git://github.com/Nuand/Simulink-MATLAB-bladeRF.git

7. Run MATLAB and setup the *MEX* compiler

    >> mex -setup

8. Switch to your Simulink-MATLAB-bladeRF directory.

9. Start the build process (in MATLAB)

    >> make.m

    If BLADERF_INC_DIR and BLADERF_LIB_DIR are not automatically found you will have to copy the include and lib directories to Simulink-MATLAB-bladeRF\deps\bladerf\ . You will also have to manually copy the appropriate bladeRF.dll, lisusb and pthread library files to Simulink-MATLAB-bladeRF\bin\ .

    Some compilers even have their problems with spaces in the library and include paths (e.g. `..\Firstname Lastname\..`). Move all bladeRF code to a location without spaces.


10. Add the *bin* and the *blockset* directory to the MATLAB path environment.

11. Place the required DLLs in the *bin* directory of bladeRF. If you downloaded the release versions of the *bladeRF* installer, simply copy all included dlls from C:\Program Files\bladeRF (x86)\x86 or C:\Program Files\bladeRF (x86)\x64 depending on your architecture into the *bin* directory. Again, make sure you copy the x64 versions if your using 64-bit MATLAB.

12. You will now find a new Toolbox named *Nuand bladeRF Software Defined Radio* in the *Simulink Library Browser*. Additionally, a simple spectrum scope model is located in the directory *demo*.

Weblinks
--------

The following table lists various weblinks which might be useful to you:

- [bladeRF](https://nuand.com/bladeRF) - Information about the Nuand bladeRF Software Defined Radio.

Copyright
---------

The Simulink-MATLAB-bladeRF source code contains code that is based on Simulink-RTL-SDR.

- *Simulink-RTL-SDR*
  Authors: Communication Engineering Lab (CEL), Karlsruhe Institute of Technology (KIT), Michael Schwall, Sebastian Koslowski
  License: GNU General Public License
  Source:  Simulink-rtlsdr/

Contact and Support
-------------------

For any questions or inquiries regarding Simulink-MATLAB-bladeRF or the bladeRF please email [bladeRF@nuand.com](mailto:bladerf@nuand.com)

- Robert Ghilduta - [robert.ghilduta@nuand.com](mailto:robert.ghilduta@nuand.com)

Please provide the following information when requesting support:

- Operating System (Linux/Windows, 32-bit/64-bit, Linux-Distribution, ...)
- MATLAB version (R20***, 32-bit/64-bit, ...)
- Compiler and version (GCC x.x.x, MVSC, ...)
- Detailed error report (MATLAB console output or GUI screen-shot)
- ...and all other information you consider as meaningful ;)


Acknowledgements
----------------

We are greatly indebted to Michael Schwall and Sebastian Koslowski for their great work with opensource radio platforms and MATLAB support. Simulink-bladeRF borrows heavily from Simulink-RTL-SDR.

Change-log
---------

- v1.0: first release of the Simulink-MATLAB-bladeRF software package

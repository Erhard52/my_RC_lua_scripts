# my_RC_lua_scripts
Lua scripts for edgeTX
swap switch assignments on your TX16S with this lua script or DOS batch program

the swapswitchFast file allows to swap the function of switches NOT sliders.
note: only swap switches with the same electrical properties like 2 positions or 3. it also switches the attached audio prompts.
the .bat file can be used on model files on the windows computer in the  command prompt or powershell windows

=============the command line should look like this ===========

USAGE:   swapswitch.bat <inputfile> <outputfile> <switch1> <switch2>

  Swaps switch1 and switch2 in both directions simultaneously.
  inputfile must be saved as ANSI encoding in Notepad++

EXAMPLE:
  .\swapswitch.bat model.yml out.yml SC SD
  Replaces all SC with SD and all SD with SC at the same time.

=====LUA script ==================
i generated this scripts with Claude AI because i never have done any lua programing before.
took me about 3 hours back and forth with claude but that is nothing compared to 2 weeks or more for manual programing.

i added a faster version 
  swapswitchFast.lua
this only takes about 15sec whereas the


i have tested this only on the TX16S (FW 2.12.0) with touch screen 
the LUA file can be loaded into the 
\scripts\tools 
directory where all the  other lua scripts reside and are executed on the radio.
more then 2 switches can be reassigned in one session.
because the modification happens on the current model file one must reboot the radio (power cycle) to make it active.

the program prompts you for inputs on the touch screen

have fun
erhard



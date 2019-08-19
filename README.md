## Introduction
XCI stands for eXtended Console Interface. This is a very experimental program written in assembler x86 (NASM syntax). The program is designed to assist in creating a simple menu-oriented console interfaces in small scripts like BAT/ps1/pl and so on. Runs on: from Windows XP to Windows 10.

## Features
Following features are currently implemented:

* Colored text output
* Cursor management (position/size/visibility)
* Formatted text (left/center/right)
* Line drawing
* Limited UTF-16 support
* A very simple event-driven menu
* Small footprint (~16KB) and no dependencies

## Cons
Currently there's *a lot*. The program is based on the fact that reinventing the wheel is a good thing, so I try to implement as much as possible by myself with my limited programming skills. Therefore:

* Almost no dynamic memory management because it's hard
* Error checking is limited. If you try to fill all the console buffer with, say, dots (.) the program will most likely crash. Try this code: `xci /L:M:. /L:F`
* No documentation. Like at all. I am currently in process of writing it. See examples to get some understanding of what this program can currently do
* UTF-16 is not implemented correctly. The program always assumes that code symbol is 2 bytes long which is not true. It covers a lot of basic character to make it usable, though
* And so on...

So, simply speaking, xci is my hobby project and playground for learning assembler, how OS Windows works on basic level (WinAPI) and git work flow.

### Installation
Not required. Just download xci.exe from the root of the project to a whatever place you want. Then open cmd.exe (Start->type 'cmd'->Enter) and change current directory to a place where you downloaded xci.exe. Say you downloaded it to 'C:\Temp', then you type `cd C:\Temp` [Enter] and now you can check out examples below.

### Examples
Let's finally see some examples.

`xci /C:C /T:RED /C:A /T: GREEN /C:9 /T: BLUE /C:7`
Will print 'RED GREEN BLUE' in their respective colors. 'C' stands for color (see `color /?` in cmd.exe for details) and 'T' is treated like text to output.

`xci /L:S:# /L:M:- /L:E:# /L:L,5`
Set the beginning of the line (/L:S) to '#', middle of the line (/L:M) to '-', end of the line (/L:E) to '#' and then draw 5 lines (/L:L,5).

`xci /@:!LOOP /T:+ /X:+2 /Y:+2 /S:500 /@:)LOOP`
Save LOOP as a goto label, then print '+' char, increase cursor's X and Y by two, sleep for 500 ms and start over. So this will print '+' in a diagonal manner until you hit CTRL+C.

`/F:R,ONE,┌,─,┐,│, ,│,└,─,┘ /B:C,=5,=25,=5,=15 /B:# /F:I,ONE`
Set up a rectangle to draw with the basic text drawing characters (/F:R,ONE), then change current drawing box (DBOX) to position `left,right,top,bottom` (/B:C), change cursor to start of the DBOX (/B:#) and finally draw the box we registered earlier (/F:I).

`cls&xci /M:P:O /x Examples\Menu.xci`
Execute a script from Examples\Menu.xci. This will show a simple menu which you can navigate using keyboard arrows or mouse.
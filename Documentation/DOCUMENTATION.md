*This document describes xci version A1.0.*

## Abstraction
The xci utility is based on a principle that everything is an argument. Everything that goes after it is a parameter to the said argument. So the following construction: `xci /C:8 /T:Test text /N` means:

* Call 'C' argument with parameter '8'
* Call 'T' argument with parameter 'Test text'
* And finally call 'N' argument without any parameters

You can think of xci as a some some of a simple conveyor with some slight possibility of control. It executes arguments and moves further forward until there's none left or xci encounters a special *control* argument like '@' - then it moves/calls a specified label. Also, some of basic arguments can be enhanced/changed with logic modifies (/M). For example, `/M:T:-c /T:CENTER` will make 'T' argument format text to center of the row.


## Brief overview
The following arguments are supported:

* **T** - Output text to screen
* **N** - Simulate new line
* **C** - Set console color
* **S** - Sleep for milliseconds
* **X** - Set X cursor position
* **Y** - Set Y cursor position
* **~** - Add/Modify variable
* **?** - Perform a check upon variable
* **L** - Draw line
* **G** - Set code page
* **M** - Modify internal logic
* **A** - Output attributes
* **B** - Set DBOX structure
* **@** - Label and logic-flow management
* **#** - Return from the last label call
* **V** - Set cursor's size/visibility
* **b** - Console buffer management
* **m** - Memory management
* **R** - Read console input
* **W** - Write to different handles (specific)
* **F** - Register/draw frames
* **E** - Register/draw active elements
* **D** - Enter navigation mode and dispatch messages
* **x** - Execute xci script
* **P** - Get arguments from pipe
* **Q** - Quit the program

## Detailed overview
Every argument takes a specific set of parameters. What is important here is the fact that program is very strict but not smart in argument processing. Each argument must be predicted with '/' and have a one character after, we're going to use ':' and there must be a one char to separate arguments from each other, we're going to use ' ' (space) character. If this structure is messed up, then xci will still try to parse it and this could lead to crash of the program. So, be attentive on the command line.

Note: All examples are designed for use in cmd.exe. For powershell, you should call xci using 'cls;.\xci [ARGUMENTS]' form.

### M argument
Modifies internal logic of a specified argument. For example, you want 'T' argument to format text on center, then you modify its logic with this argument before calling 'T' itself.

#### Synopsis
/M:[ARGUMENT TO MODIFY]:[FLAGS]

* [ARGUMENT TO MODIFY] - Can be any valid xci argument that have 'Logic modifiers' section, currently 'T', 'P' and 'A'. Can also be a special flag '#' which means modify global flags (see below)
* [FLAGS] - Is a set of one-character flags for the [ARGUMENT TO MODIFY] except for special characters, which are:
  * '-' - Leave current flag as is
  * '.' - Reset the flag to default value

/M:[+|=][NAME] - Save/restore current set of flags to a variable:

* [+] - Save to variable
* [-] - Restore from variable
* [NAME] - Name of variable to save to/restore from

/M:! - Restore all flags to default values

#### Global flags
Beside of local flags that belongs to a special argument, there are also global flags, that affects every procedure. Global flags are set using '#' and can be:

* '1' - Working with internal/external cursor if set to a non-zero value. Procedures like 'T/L/A' will use internal position. Position of an actual console cursor won't change.
* '2' - If set to non-zero value will perform variable expansion for procedures that supports it, like 'T'

It's best to illustrate the 'M' argument by example: `cls&xci /M:T:-c /T:CENTER /M:T:-l /T:LEFT /M:T:-. /T:!!!` - We set the second flag of 'T' argument to 'c' which means 'format to center', then we set it to 'l' - format to left and finally, we reset it to default, which means 'do not format' and '!!!' will end up at the current cursor position

### ~ argument
Sets a variable in program's internal memory. The buffer is currently small, only 8192 bytes.

#### Synopsis
/~:[NAME],[TYPE],=,[VALUE] - 4 parameters form is for registration of a new variable:

* [NAME] - Name for your variable
* [TYPE] - Type for variable. 'T' - Text variable, 'N' - Numeric variable
* = - Means set the initial value
* [VALUE] - New value for variable

/~:[NAME],[ACTION],[VALUE] - 3 parameters form is for changing an already existing variable:

* [NAME] - Name of previously declared variable
* [ACTION] - Action appropriate for variable of registered TYPE (see below)
* [VALUE] - Value for ACTION

ACTION is depending on TYPE of variable.
For TEXT variables it can be:

* **=** Replace with new text
* **(** Add text to the left
* **)** Add text to the right

For NUMERIC variables:

* **=** - Assign new value
* **+/-** - Add/subtract the value from current
* **C,C_NUM** - Convert NUMERIC variable to TEXT variable called C_NUM

Example 1: `cls&xci /M:#:-Y /~:Test,T,=,TEXT /T:My variable is: ~Test~` - Remember about '/M:#'? We set second global flag to allow variable expansion

Example 2: `cls&xci /M:#:-Y /~:COUNTER,N,=,10 /T:Self-destruct sequence after. /@:!LOOP /~:COUNTER,C,CURRENT /T:~CURRENT~. /S:1000 /?:COUNTER,ne,0 /~:COUNTER,( /@:)LOOP /! /C:CF /T:!!!BOOM!!! /C:7` - This one is a bit complex, see '@' and '?/!' arguments first to understand this

### ? and ! arguments
Checks if expression match and execute an xci block till the /! argument.

#### Synopsis

/?:[NAME],[PREFIX],VALUE - where:

* [NAME] - Name of variable to check upon
* [PREFIX] - Comparison prefix: eq/ne - equals/not, le/ge - lesser/greater or equal, ls/gt - lesser/greater
* [VALUE] - Value to compare against

/?:![EVENT],[PARAMETERS] - Special case when in dispatch loop (see 'D' argument)

Example: `cls&xci /~:VAR,N,=,20 /?:VAR,eq,20 /T:TRUE, obviously! /! /N /T:Will show anyway because out of block /N`

### @ and # arguments
Logic flow management. This argument allows you to jump to labels (goto) and register/call procedures.

#### Synopsis

/@:!LABEL - Registers a LABEL. You can jump to it later

/@:=PROCEDURE - Registers a PROCEDURE. You can call it later

/@:This is a comment - Form without prefixes is a simple comment and will be skipped

/@:)LABEL - Jump to previously registered LABEL. Can be used only with labels

/@:(PROCEDURE - Call previously registered PROCEDURE. Can be used only with procedures

The difference between GOTO and PROCEDURE is that GOTO label won't skip arguments following it and won't return anywhere. PROCEDURE will skip all arguments following it until the closing '/#' argument and after call will return exactly where it was called.

Example: `cls&xci /@:=WhoAmI? /S:1000 /T:Darkwing Duck /# /T:I am... /@:(WhoAmI? /@:We'll return here after the call and add the exclamation mark /T:!`

### T argument
This argument takes only one parameter - text to output on screen.
Although, parameter can be be only one, this argument have a lot of logic modifiers.

Example: `cls&xci /T:Pay attention, that you don't need to escape any "quotes". The only character that needs escaping is the argument symbol - \/ and special characters of your shell like redirection symbols`

#### Logic modifiers
* 1 - Adjust cursor position after writing. If set to non-zero then xci will NOT adjust position, otherwise position will be adjusted after each write (default). Compare: `cls&xci /T:-- /T:++` and `cls&xci /M:T:N /T:-- /S:1000 /T:++`
* 2 - Format text in a row. Can be 'l' - format to left, 'c' - format to center, 'r' - format to right. If set to zero, then no formatting will be performed (default). Example: `cls&xci /M:T:-c /T:CENTER`
* 3 - Format to column. Can be 't' - format to top, 'c' - format to center, 'b' - format to bottom. Example: `cls&xci /M:T:--b /T:BOTTOM`
* 4 - Perform expansion of complex string if set to non-zero. Example: `cls&xci /M:T:---Y /T:One[d9]Two[d9]Three` - tab formatted output
* 5 - Format text on several 'T' arguments. It's very useful if you want to format a line with multiple colors in it. Takes a number between 1 and 9 which represents *additional* amount of 'T' arguments to base formatting on after the initial 'T' call. Example: `cls&xci /M:T:-c--2 /C:9 /T:Sonic. /C:E /T:Tails. /C:C /T:Knuckles. /C:7`
* 6 - Write by whole line if set to non-zero value. The character to fill the line is taken from /L:M parameter. Example: `cls&xci /M:T:-c---Y /L:M:! /T:WARNING`

### N argument
Doesn't take any parameters.
It "simulates" the new line. Simulating means it sets X to 0 and Y plus 1 instead of writing the "\n" character. Side effect of this is that it stops working after reaching the end of console buffer. See the example below.

Example: `cls&xci /@:!LOOP /T:. /N /S:10 /@:)LOOP`
After a while the N argument will stop working because we reached the end of console buffer. Hit CTRL+C to terminate the program

### C argument
Set current console color. Takes a HEX number as parameter.
The following colors are supported:

    0 = Black       8 = Gray
    1 = Blue        9 = Light Blue
    2 = Green       A = Light Green
    3 = Aqua        B = Light Aqua
    4 = Red         C = Light Red
    5 = Purple      D = Light Purple
    6 = Yellow      E = Light Yellow
    7 = White       F = Bright White

First number is background color and second one is foreground.

Example: `cls&xci /C:C0 /T:BLACK ON RED /C:0C /N /T:RED ON BLACK /C:7`

### S argument
Simply waits for specified number of milliseconds, then continues execution.
Takes a number of milliseconds to sleep.

Example: `cls&xci /T:Sonic sez /S:500 /T:. /S:500 /T:. /S:500 /T:. /S:500 /C:9F /T:THAT'S NO GOOD! /C:7`

### X and Y arguments
Set X or Y position of cursor to the specified amount.

#### Synopsis
/X:[CALCULATE][NUMBER]

/Y:[CALCULATE][NUMBER]

Where [CALCULATE] is a special structure with one of possible prefixes:

* **(** - Decrement current value
* **)** - Increment current value
* **+** - Add to current value
* **-** - Subtract from current value
* **=** - Assign new value
* **.** - Leave current value as is

[NUMBER] is a number to add/subtract/assign to current cursor position.

Example: `cls&xci /@:!LOOP /T:. /X:) /Y:+2 /S:100 /@:)LOOP` - write diagonal lines of '.' character until user hits CTRL+C. /X:) will increment current X value, /Y:+2 will increase Y by 2

### L argument
Draw lines. You can't really draw a line in console, it has to be constructed from an appropriate character like '-' or even better the pseudo graphic block from Unicode.

#### Synopsis

Construction forms:

/L:S,[CHARS] - Set START of the line

/L:M,[CHARS] - Set MIDDLE of the line

/L:E,[CHARS] - Set END of the line

/L:R - Reset all forms to default (NULL)

Note: [CHARS] are limited to 3 characters MAX. In order to draw a line, at least one construction form must be specified.

Drawing forms:

/L:C,[SIZE] - Draw line [SIZE] long

/L:L,[COUNT] - Draw a full line (equals to size of the console row) number of times

/L:F - Fill the whole DBOX (see 'B' argument before experimenting)

Example: `cls&xci /L:S,) /L:M,- /L:E,( /L:C,40 /N /L:L,2 /L:R /L:M:. /L:L,1`

### B argument
Sets the current DBOX (Drawing BOX). DBOX defines the area to draw for all other arguments like 'T', 'A', 'L', etc.

#### Synopsis

/B:C,[CALCULATE_DBOX] - Change current DBOX:

* [CALCULATE_DBOX] - 4 numbers separated by comma with CALCULATE prefix (see X and Y arguments):
  * [CALCULATE]DBOX ROW LEFT - Left corner of the rectangle
  * [CALCULATE]DBOX ROW RIGHT - Right corner of the rectangle
  * [CALCULATE]DBOX COLUMN TOP - Top of the rectangle 
  * [CALCULATE]DBOX COLUMN BOTTOM - Bottom of the rectangle

See the diagram below for better understanding.

/B:R - Reset DBOX to the initial size of the console buffer

/B:# - Set mouse position to start of DBOX: X = DBOX ROW LEFT, Y = DBOX COLUMN TOP

/B:A,[NAME],[DBOX] - Register new DBOX, where:

* [NAME] - Name of new DBOX
* [DBOX] - 4 numbers structure separated by comma without [CALCULATE] prefix

/B:S,[NAME] - Select previously registered DBOX by [NAME]

To make it more clear how DBOX works, here's a diagram:

        |CONSOLE ROW LEFT----------CONSOLE COLUMN TOP------------CONSOLE ROW RIGHT|
        |                                                                         |
        |        |DBOX ROW LEFT----DBOX COLUMN TOP------DBOX ROW RIGHT---|        |
        |        |                                                       |        |
        |        |                                                       |        |
        |        |                                                       |        |
        |        |DBOX ROW LEFT----DBOX COLUMN BOTTOM---DBOX ROW RIGHT---|        |
        |                                                                         |
        |                                                                         |
        |CONSOLE ROW LEFT----------CONSOLE COLUMN BOTTOM---------CONSOLE ROW RIGHT|

So think of it as a window inside the console buffer that, by default, equals to it but can be adjusted later.

Example: `cls&xci /B:C,=0,=10,=0,=10 /L:M,- /L:F /B:C,+10,+10,.,. /L:M,+ /L:F`

### G argument
Sets current console codepage. It acts identically to cmd.exe's `chcp` command. Takes a copegade number as a parameter.

Example: `xci /G:10000` - Now your console session is in UTF-16 mode and some console programs might work in some weird way

### A argument
Writes attributes to the console screen buffer.
Takes a set of colors (see 'C' argument) separated by comma.

Example: `cls&xci /T:Christmas! /A:C,A,F,C,A,F,C,A,F,C`

### V argument
Manages the size and visibility of the cursor.

#### Synopsis

/V:V,[0|1] - Cursor is visible (1) or not (0)

/V:S,[1-100] - Size of the cursor from the smallest (1) to the biggest (100)

Example: `cls&xci /T:I am tiny:  /V:S,1 /S:4000 /N /T:I am BIG:  /V:S,100 /S:4000 /N /T:Now you can't see me:  /V:V,0 /S:4000 /N /T:Now you do:  /V:V,1 /S:4000`

### b argument
Creates a shadow console buffer. It can reduce flickering if you deal with a lot of drawing.

#### Synopsis

/b:C - Creates a shadow console buffer equal to current DBOX

/b:~ - Switch buffer for output

/b:Y - Copy from shadow buffer to current

Example: `cls&xci /B:C,=0,=40,=0,=20 /b:C /b:~ /L:M,-=- /L:F /b:~ /T:We drew lines in our shadow buffer. /N /T:Now to copy it in one swift move... /S:2000 /b:~ /b:Y`

### m argument
By default, xci only requests 8KB of RAM for storing arguments and data. It's enough for small scripts, but if you try something big, the program will quickly exceed the memory limit and crush. With this argument you can request more than 8K bytes.

#### Synopsis

/m:A,[SIZE] - SIZE in bytes for argument array

/m:D,[SIZE] - SIZE in bytes for data array

Example 1: `cls&xci /L:M,- /L:F` - This will most likely crush or produce weird results because the size of console buffer is much bigger than current memory limit

Example 2: `cls&xci /m:D,3145728 /L:M,- /L:F` - This one will probably work because 3MB of RAM should be enough for default console buffer

### R argument
Read keys/chars/lines from console input.

#### Synopsis

/R:[C|K|L|l],[SIZE] where:

* 'C' - read characters, 'K' - read keys, 'L' - read lines, 'l' - read lines without echoing back
* [SIZE] is how much to read.

/R:T,[TIMEOUT],[DEFAULT CHAR],[C|K|L|l],[SIZE] - Same as previous but with read timeout:

* [TIMEOUT] - Read timeout in milliseconds
* [DEFAULT CHAR/KEY/LINE] - What character/key/lines to return if timeout is expired

Note: See 'W' argument to get an example of actually useful use case for this argument.

Example: `cls&xci /T:Enter character: /R:C,1 /T: [ /W:R /T:] /N /T:Now enter line [SKIP is default]: /R:T,10000,SKIP,L,1 /T:Entered:  /W:R`

### W argument
Write data to different handles. It actually similar to 'T' argument but takes input from various internal buffers (like from 'R' argument) and then writes it back to console/file/etc.

#### Synopsis

/W:R,[GR] - Read from, then write to:

* G - Write back using 'T' procedure
* R - Write as raw data. It can be read by other console applications, such as cmd.exe

Example for cmd.exe: `For /F %i IN ('"xci /R:T,5000,N,K,1 /W:R,R"') DO Set CH=%i` - 'CH' now contains the read key you can check by running `echo %CH%`

### F argument
Registers a frame. Frame is set of chars that are used to construct an edge around DBOX.

#### Synopsis

/F:R:[NAME],[FRAME] - Register a new frame

* [NAME] - Name for a new frame variable
* [FRAME] - Characters to construct a frame separated by comma: TOP_LEFT,TOP_CENTER,TOP_RIGHT,MIDDLE_LEFT,MIDDLE_CENTER,MIDDLE_RIGHT,BOTTOM_LEFT,BOTTOM_CENTER,BOTTOM_RIGHT

/F:I,[NAME] - Draw frame inside DBOX

/F:O,[NAME] - Draw frame outside DBOX

Example: `cls&xci /F:R,ONE,┌,─,┐,│, ,│,└,─,┘ /B:C:=10,=20,=10,=20 /X:=0 /Y:=0 /F:O,ONE /F:I,ONE /N /S:2000`

### E and D arguments
Register an active elements. You can think of them as buttons or actually anything that you can be drawn on console screen. Those 'active' elements gets called later when you enter event-driven loop in '/D:D' argument.

#### Synopsis
/E:R,[NAME],[DBOX],[PROCEDURE]

* NAME - Name for the element
* DBOX - DBOX structure (see 'B' argument) that determines the size of active element
* PROCEDURE - Previously registered procedure for the label (see '@' argument)

The 'D' argument enters a forever loop listening to console events and then dispatches them to registered active elements. It supports navigation using arrow keys and mouse. Currently accepts only 'D' parameter which means Dispatch.

#### Dispatch loop
When you specify '/D:D' xci enters a loop and performs navigation between registered buttons. It sends following messages to its elements that you might want to process:

* 'D' - Draw event. You should perform initial drawing for your element. Comparison form: `/?:!,D *xci instructions* /!`
* 'S' - Select event. User chose an element using mouse or navigational buttons. Comparison form: /?:!,S *xci instructions* /!
* 'K' - Key event. User hit a key. Comparison form: `/?:!,K,[STATE],[KEY] *xci instructions* /!` where [STATE] can be 'U' for key up and 'D' for key down, [KEY] is a scan code to compare against
* 'M' - Mouse event. Comparison form: `/?:!,M,[TYPE],[KEY] *xci instructions* /!` where [TYPE] is 'C' for standard click or 'D' for double click, [KEY] is mouse key: 1 - left, 2 - right

So, first you create a procedure ('@') that processes above events, then you register an active element ('E') and finally enter loop ('/D:D').

Example: `cls&xci /V:V,0 /T:DOOM is a greatest game of all time: /@:=B1 /?:!,D /C:7 /B:# /T:NO /! /?:!,S /C:CF /B:# /T:NO /! /?:!,K,D,[hD] /V:V,1 /C:7 /Q:1 /! /# /@:=B2 /?:!,D /C:7 /B:# /T:YES /! /?:!,S /C:2F /B:# /T:YES /! /?:!,K,D,[hD] /V:V,1 /C:7 /Q:2 /! /# /E:R:E1,37,40,0,0,B1 /E:R:E2,41,45,0,0,B2 /D:D` - This is hell, right? It's actually not so complicated if you put it in a script (see more complicated example in 'x' argument). But anyway, this command line will register two buttons 'YES' and 'NO', then will enter dispatch loop until you hit [ENTER]. Upon exit it will set %ERRORLEVEL% to '1' or '2' depending on which button you hit.

### P argument
Listen for arguments from pipe. In this case xci acts as a server. It blocks until there's something in the pipe, then processes it and goes back to listening again.

#### Logic modifiers
* 1 - From what codepage is to convert input. This is a mandatory flag you need to specify. Can be: 'O' - OEM codepage, 'A' - ANSI, 'U' - UTF-8

Example: `xci /M:P:O /P:\\.\pipe\xci` - Now open another cmd.exe and execute `echo /T:From other console /N /Q > \\.\pipe\xci`

### x argument
Run an xci script. It almost the same as command line but you can format arguments in a more human-readable format. Also, limit for MAX_ARGUMENTS is lifted (which is 8192 bytes in cmd.exe if I am not mistaken). All new lines and initial indentations (tab/spaces) are ignored.

*Note*: You have to specify '/M:P:?' flag so xci knows what codepage the script file in. Input codepage flag should be in global set ('#') though, I will change it in the future versions.

Example: `cls&xci /M:P:O /x:Examples\Menu.xci` - You need to be in folder where you unpacked xci release in order for xci to find the requested script.

### Q argument
Exit program. By default, exits with zero code if not specified.

Example: `xci /Q:42` - Set exit code to be as meaningful as life
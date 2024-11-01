<#
nano-for-windows

Majority of patches and the original GH Actions workflow this script is based on
made by okibcn@github and rasa@github

Rewrite into pwsh, small tweaks to certain patches, and certain patches in their
entirety by helpimnotdrowning@github <www.helpimnotdrowning.net>

---

nano-for-windows is free software: you can redistribute it and/or modify it
under the terms of the GNU General Public License as published by the Free
Software Foundation, either version 3 of the License, or (at your option) any
later version.

nano-for-windows is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with
nano-for-windows. If not, see <https://www.gnu.org/licenses/>.
#>

. ./functions.ps1

$PSNativeCommandUseErrorActionPreference = $true
$Origin = pwd

$ErrorActionPreference = "Stop"
rm -rf $Origin/nano

<##############################

Get sources & stuff

##############################>

if ($env:NFW_NANO_BRANCH_OR_COMMIT) {
	git clone git://git.savannah.gnu.org/nano.git
	cd nano
	git reset --hard $env:NFW_NANO_BRANCH_OR_COMMIT
	cd ..
	
} else {
	# latest
	git clone git://git.savannah.gnu.org/nano.git
	
}
	
cd nano

git clone https://github.com/Bill-Gray/PDCursesMod.git curses --depth=1
git clone git://git.savannah.gnu.org/gnulib.git --depth=1

autopoint --force

./gnulib/gnulib-tool --import futimens getdelim getline getopt-gnu glob `
		isblank iswblank lstat mkstemps nl_langinfo regex sigaction `
		snprintf-posix stdarg strcase strcasestr-simple strnlen sys_wait `
		vsnprintf-posix wchar wctype-h wcwidth
aclocal -I m4
autoconf
autoheader
automake --add-missing
$ErrorActionPreference = "Continue"


<##############################

Nano patches

##############################>

_notify_patch "POSIX realpath -> MS CRT _fullpath | missing function workaround"
_backup src/definitions.h
@"

#ifdef _WIN32
# include <windows.h>
# include "uniwidth.h"
# define realpath(N, R) _fullpath((R), (N), 0)
#endif

"@ >> src/definitions.h
_diff



_notify_patch "POSIX `$HOME -> WINDOWS `$USERPROFILE | missing env workaround"
Edit-FileByLine -B -Search Plain -Pattern '"HOME"' -Replacement '"USERPROFILE"' -Path src/utils.c
_diff



_notify_patch "POSIX `$TMPDIR -> WINDOWS `$TEMP | missing env workaround"
Edit-FileByLine -B -Search Plain -Pattern "TMPDIR" -Replacement "TEMP" -Path src/files.c
# _diff #


_notify_patch "convert invalid filename characters -> ! for backup files"
Edit-FileByLine -B -Search Plain -Pattern "if (thename[i] == '/')" -Replacement "if (strchr(`"<>:\`"/\\|?*`", thename[i]))" -Path src/files.c
Edit-FileByLine -Search Plain -Pattern "/tmp/" -Replacement "~/Appdata/Local/Temp" -Path src/files.c
_diff



_notify_patch "internally convert Windows '\' to POSIX '/' "
Edit-FileByLine -B -Search Plain -Pattern "	free(tilded);" -Replacement @"
	free(tilded);
	for(tilded = retval; *tilded; ++tilded) if(*tilded == '\\') *tilded = '/';
"@ -Path src/files.c
Edit-FileByLine -Search Plain -Pattern "path[i] != '/'" -Replacement "path[i] != '/' && path[i] != '\\'" -Path src/files.c
_diff



_notify_patch "always open files in binary mode, avoid Windows text mode translation see https://learn.microsoft.com/en-us/cpp/c-runtime-library/translation-mode-constants for more info"
Edit-FileByLine -B -Search Plain -Pattern "O_RDONLY" -Replacement "O_RDONLY | _O_BINARY" -Path src/files.c
Edit-FileByLine -Search Plain -Pattern "O_WRONLY" -Replacement "O_WRONLY | _O_BINARY" -Path src/files.c
_diff

Edit-FileByLine -B -Search Plain -Pattern "O_RDONLY" -Replacement "O_RDONLY | _O_BINARY" -Path src/text.c
Edit-FileByLine -Search Plain -Pattern "O_WRONLY" -Replacement "O_WRONLY | _O_BINARY" -Path src/text.c
_diff

# TESTING THIS MIGHT BREAK
Edit-FileByLine -B -Search Plain -Pattern "O_RDONLY" -Replacement "O_RDONLY | _O_BINARY" -Path src/nano.c
Edit-FileByLine -Search Plain -Pattern "O_WRONLY" -Replacement "O_WRONLY | _O_BINARY" -Path src/nano.c
_diff



_notify_patch "enable UTF-8 terminal"
Edit-FileByLine -B -Search Plain -Pattern "vt220" -Replacement "" -Path src/nano.c

_notify_patch "remove references to ANSI escape codes (SUBJECT TO REMOVAL)"
Edit-FileByLine -Search Regex -Pattern ".*x1B.*" -Replacement "" -Path src/nano.c

_notify_patch "POSIX nl_langinfo -> C standard setlocale | missing function workaround"
Edit-FileByLine -Search Regex -Pattern ".*nl_langinfo\(CODESET\).*" -Replacement "setlocale(LC_ALL, `"`");" -Path src/nano.c
_diff



# the following patch is no longer applicable as of nano commit 86b83888891213d473ea077e2b50bdeba9171103
# Allow custom colors in terminals with more than 256 colors
#echo -e "\n\nPATCH: Allow true color."
#sed -i.bak "/COLORS == 256/ {s/==/>=/}"  src/rcfile.c
#_diff



_notify_patch "window resize crash fix"
Edit-FileByLine -B -Search Plain -Pattern "LINES and COLS accordingly. */" -ActionDeleteNextNLines 2 -Path src/nano.c
Edit-FileByLine -Search Plain -Pattern "LINES and COLS accordingly. */" -Replacement @"
LINES and COLS accordingly. */
	resize_term(0, 0);
	erase();
"@  -Path src/nano.c
Edit-FileByLine -Search Plain -Pattern "recreate the subwindows with their (new) sizes" -ActionDeleteNextNLines 1 -Path src/nano.c
_diff

Edit-FileByLine -B -Search Plain -Pattern "the_window_resized" -Replacement "input == KEY_RESIZE" -Path src/winio.c
_diff



_notify_patch "fix deadlock/delay with unicode characters"
Edit-FileByLine -B -Search Plain -Pattern "halfdelay(ISSET(QUICK_BLANK)" -DeleteThroughSearchType Plain -DeleteThrough "disable_kb_interrupt" -Path src/winio.c
_diff



# this patch will not be included because I dont like it
# Add (Y/N/^C) to Save modified buffer prompt
#echo -e "\n\nPATCH: More info for exit message."
#sed -i.bak "s|Save modified buffer|& (Y/N/^C)|"  src/nano.c
#_diff



_notify_patch "fix browser folder change"
Edit-FileByLine -B -Search Plain -Pattern "--selected" -Replacement "selected = 0" -Path src/browser.c
_diff



_notify_patch "fix unicode character width detection"
Edit-FileByLine -B -Search Plain -Pattern "wcwidth(wc)" -Replacement "uc_width(wc, `"UTF-8`")" -Path src/chars.c
Edit-FileByLine -B -Search Plain -Pattern "wcwidth(wc)" -Replacement "uc_width(wc, `"UTF-8`")" -Path src/winio.c
Edit-FileByLine -Search Plain -Pattern "#include `"prototypes.h`"" -Replacement @"
#include "prototypes.h"
#include "uniwidth.h"
"@ -Path src/chars.c
_diff



_notify_patch "fix pipe-in data in Windows console"
Edit-FileByLine -B -Search Plain -Pattern "/dev/tty" -Replacement "CON" -Path src/nano.c
Edit-FileByLine -Search Plain -Pattern "stream, 0" -Replacement "stream, fd" -Path src/nano.c
Edit-FileByLine -Search Plain -Pattern "	FILE *stream;" -DeleteThroughSearchType Plain -DeleteThrough "stop the reading" -Replacement @"
	static FILE *stream;
	static int fd=0;
	if (fd == 0){
		if (GetConsoleWindow() != NULL)
			fprintf(stderr, _("Reading data from keyboard; type a ^Z line to finish.\n"));
		fd = dup(0);
		stream = fdopen(fd, "rb");
		freopen("CON", "rb", stdin);
		FreeConsole();
		AttachConsole(ATTACH_PARENT_PROCESS);
		return FALSE;
	}
	
	endwin();
	
	if (stream == NULL) {
		int errnumber = errno;
		
		if (fd > -1)
			close(fd);
			
		return FALSE;
	}
"@ -Path src/nano.c

Edit-FileByLine -Search Plain -Pattern "	/* Enter into curses mode.  Abort if this fails. */" -Replacement @"
	/* Enter into curses mode.  Abort if this fails. */
	for(int optind_ = optind; optind_ < argc; optind_++) {
		if (strcmp(argv[optind_], "-") == 0) {
			scoop_stdin();
			break;
		}
	}
"@ -Path src/nano.c
_diff



_notify_patch "NEW: use `$ProgramData env instead of SYSCONFDIR, give nanorc its own directory (Windows convention)"
Edit-FileByLine -B -Search Plain -Pattern "nanorc = mallocstrcpy(nanorc, SYSCONFDIR `"/nanorc`");" -Replacement @"
	{	const char* win_programdata = getenv("ProgramData");
		
		if (win_programdata == NULL) {
			nanorc = mallocstrcpy(nanorc, "C:/ProgramData");
			
		} else {
			nanorc = mallocstrcpy(nanorc, win_programdata);
			
			// replace dos backslashes with *nix forward slashes
			for (size_t i = 0; win_programdata[i] != '\0'; i++) {
				if (win_programdata[i] == '\\') {
					nanorc[i] = '/';
					
				}
			}
		}
		
		nanorc = concatenate(nanorc, "/nano-for-windows/nanorc");
		
	}
"@ -Path src/rcfile.c
_diff



<##############################

PDCursesMod patches

##############################>

_notify_patch "remove duplicate definitions"
Edit-FileByLine -B -Search Regex -Pattern ".*0x42[1234].*" -Replacement "" -Path src/definitions.h
_diff



_notify_patch "256 -> true color support"
Edit-FileByLine -B -Search Plain -Pattern "int interface_color_pair" -Replacement "chtype interface_color_pair" -Path src/prototypes.h
Edit-FileByLine -B -Search Plain -Pattern "int interface_color_pair" -Replacement "chtype interface_color_pair" -Path src/global.c
_diff

Edit-FileByLine -B -Search Plain -Pattern "int attributes" -Replacement "chtype attributes" -Path src/definitions.h
_diff

Edit-FileByLine -B -Search Plain -Pattern "int *attributes" -Replacement "chtype *attributes" -Path src/rcfile.c
Edit-FileByLine -B -Search Plain -Pattern "int attributes" -Replacement "chtype attributes" -Path src/rcfile.c
_diff



_notify_patch "full modifier key detection"
Edit-FileByLine -B -Search Plain -Pattern "get_kbinput(midwin, VISIBLE);" -Replacement @"
get_kbinput(midwin, VISIBLE);
	if (!((PDC_get_key_modifiers()) & (PDC_KEY_MODIFIER_SHIFT|PDC_KEY_MODIFIER_CONTROL|PDC_KEY_MODIFIER_ALT)) ) {
		switch (input) {
			case 0x08:    input = KEY_BACKSPACE; break;
			case 0x0d:    input = KEY_ENTER;
		}
	}
	
	if (PDC_get_key_modifiers() & PDC_KEY_MODIFIER_CONTROL){
		switch (input) {
			case '/':          input = 31; break;
			case SHIFT_DELETE: input = CONTROL_SHIFT_DELETE; break;
		}
	}
"@ -Path src/nano.c

Edit-FileByLine -B -Search Plain -Pattern '"M-{", 0' -Replacement '"M-{", ALT_RBRACKET' -Path src/global.c
Edit-FileByLine -Search Plain -Pattern '"M-}", 0' -Replacement '"M-}", ALT_LBRACKET' -Path src/global.c

Edit-FileByLine -B -Search Plain -Pattern "#define CONTROL_LEFT    0x401" -DeleteThroughSearchType Plain -DeleteThrough "#define CONTROL_DELETE  0x40D" -Replacement @"
#define CONTROL_LEFT    CTL_LEFT
#define CONTROL_RIGHT   CTL_RIGHT
#define CONTROL_UP      CTL_UP
#define CONTROL_DOWN    CTL_DOWN
#define CONTROL_HOME    CTL_HOME
#define CONTROL_END     CTL_END
#define CONTROL_DELETE  CTL_DEL
"@ -Path src/definitions.h

Edit-FileByLine -Search Plain -Pattern "#define ALT_PAGEUP    0x427" -DeleteThroughSearch Plain -DeleteThrough "#define ALT_DELETE    0x42D" -Replacement @"
#define ALT_PAGEUP    ALT_PGUP
#define ALT_PAGEDOWN  ALT_PGDN
#define ALT_INSERT    ALT_INS
#define ALT_DELETE    ALT_DEL
"@ -path src/definitions.h
_diff



_notify_patch "force wchar_t to be 32 bits wide like Linux"
_backup src/definitions.h
_backup curses/curses.h
# prepend this to files by overwriting first, then writing in the backup file
"#define wchar_t int" > src/definitions.h
"#define wchar_t int" > curses/curses.h
Get-Content src/definitions.h.bak >> src/definitions.h
Get-Content curses/curses.h.bak >> curses/curses.h
_diff



_notify_patch "fix emoji input/output and transparent background"
_backup curses/pdcurses/getch.c
_backup curses/wincon/pdckbd.c
_backup curses/wincon/pdcdisp.c
Copy-Item -path $Origin/patches/getch.c -Destination curses/pdcurses/
Copy-Item -path $Origin/patches/pdckbd.c -Destination curses/wincon/
Copy-Item -path $Origin/patches/pdcdisp.c -Destination curses/wincon/
_diff



_notify_patch "fix alt+[number] and alt+[alpha] not working"
Edit-FileByLine -B -Search Plain -Pattern "char)keystring[2])" -replacement "char)keystring[2]) + ((unsigned char) keystring[2] >= '9' ? ALT_A - (int)'a' : ALT_0 - (int)'0')" -Path src/global.c
_diff



_notify_patch "fix shift+alt+[alpha] not working with PDCursesMod"
Edit-FileByLine -B -Search Plain -Pattern "if (escapes == 0) {" -Replacement @"
if (escapes == 0) {
		meta_key = PDC_get_key_modifiers() & PDC_KEY_MODIFIER_ALT;
"@ -Path src/winio.c
_diff




<##############################

LLVM-MinGW patch

##############################>

# no such thing as 'x' permission on Windows!
_notify_patch "POSIX 'x' PERMISSION -> PORTABLE'r' PERMISSION | unimplemented permission workaround"
Edit-FileByLine -B -Search Plain -Pattern "X_OK" -Replacement "R_OK" -Path src/files.c
_diff

## branding
cd curses
$CursesMajor = grep -F "#define PDC_VER_MAJOR" curses.h | grep -oP "\d+"
$CursesMinor = grep -F "#define PDC_VER_MINOR" curses.h | grep -oP "\d+"
$CursesPatch = grep -F "#define PDC_VER_CHANGE" curses.h | grep -oP "\d+"

$CursesYear = grep -F "#define PDC_VER_YEAR" curses.h | grep -oP "\d+"
$CursesMonth = grep -F "#define PDC_VER_MONTH" curses.h | grep -oP "\d+"
$CursesDay = grep -F "#define PDC_VER_DAY" curses.h | grep -oP "\d+"

$CursesVersion = "v$CursesMajor.$CursesMinor.$CursesPatch"
$CursesDate = Get-Date -Year $CursesYear -Month $CursesMonth -Day $CursesDay -AsUTC -Format "yyyy.MM.dd"
$CursesCommit = git rev-parse --short HEAD

$CursesTag = "PDCursesMod $CursesVersion build $CursesCommit, $CursesDate"

cd..

Edit-FileByLine -B -Search Plain -Pattern "GNU nano from git" -Replacement "GNU nano based off git" -Path src/nano.c
Edit-FileByLine -Search Plain -Pattern "Compiled options" -Replacement `
"Project info at https://github.com/helpimnotdrowning/nano-for-windows\n Using $CursesTag\n Compiled options" -Path src/nano.c
_diff



### COMPILING (AMD64 ONLY!!!)

<##############################

Building curses

##############################>

$PDTERM = "wincon"
$env:CFLAGS = "-O3 -fno-math-errno -flto"
cd $Origin/nano/curses/$PDTERM
make -j $([Environment]::ProcessorCount * 2) WIDE=Y UTF8=Y _w64=Y



<##############################

Configuring nano

##############################>

cd $Origin # proj root
$NfWCommit = git rev-parse --short HEAD

$BuildTarget = "x86_64-w64-mingw32"
$OutDir = "$Origin/nano/pkg"
$CursesDir = "$Origin/nano/curses"

$env:CFLAGS = "-O3 -fno-math-errno -flto -DPDC_FORCE_UTF8 -DPDC_NCMOUSE"
$env:LDFLAGS = "-L$CursesDir/$PDTERM -static -static-libgcc $CursesDir/$PDTERM/pdcurses.a"
$env:NCURSESW_CFLAGS = "-I$CursesDir -DNCURSES_STATIC -DENABLE_MOUSE"
$env:NCURSESW_LIBS = "-l:pdcurses.a -lwinmm"
$env:LIBS = "-lbcrypt"

mkdir -p "$Origin/nano/build"
cd $Origin/nano

$NanoDes = (git describe)

$EnableFeatures  = "utf8", "threads=windows" | % { "--enable-$_" }
$DisableFeatures = "nls", "speller" | % { "--disable-$_" }

gci
./configure --host="$BuildTarget" --prefix="$OutDir" @EnableFeatures `
	@DisableFeatures #--sysconfdir="C:/ProgramData/nano-for-windows" # << not needed with ProgramData patch

@"
#define HAVE_FREXP_IN_LIBC 1
#define HAVE_FREXPL_IN_LIBC 1
#define HAVE_SNPRINTF_RETVAL_C99 1
#define HAVE_SNPRINTF_TRUNCATION_C99 1
#define MBRTOWC_EMPTY_INPUT_BUG 1
"@ >> build/config.h

# nuke:
# NEED_PRINTF_DIRECTIVE_A
# NEED_PRINTF_DIRECTIVE_F
# NEED_PRINTF_FLAG_GROUPING
# NEED_PRINTF_FLAG_ZERO
# NEED_PRINTF_INFINITE_DOUBLE
# NEED_PRINTF_UNBOUNDED_PRECISION
Edit-FileByLine -SearchType Regex -Pattern ".*NEED_PRINTF_(DIRECTIVE_[AF]|FLAG_(GROUPING|ZERO)|INFINITE_DOUBLE|UNBOUNDED_PRECISION).*" -Replacement "" -Path build/config.h

$Date = Get-Date -AsUTC -Format yyyy-MM-dd
$Branding = "GNU nano $NanoDes + nano-for-windows @ $NfWCommit ($Date)"
"#define REVISION `"$Branding`" //" > src/revision.h



<##############################

Building nano

##############################>

$ErrorActionPreference = "Stop"
make -j $([Environment]::ProcessorCount * 2) && make install
$ErrorActionPreference = "Continue"



<##############################

Package nano

##############################>

cd $Origin/nano/pkg

cp $Origin/LICENSE .
cp $Origin/README.md .
mv ./bin/nano.exe .
mv ./share/doc/nano/* .
mv $Origin/nano/doc/sample.nanorc.in .nanorc
mv ./share/nano syntax
rm -rf ./bin/ ./share/ ./rnano*

strip -s nano.exe
upx --lzma --best nano.exe
gci -force

# tar -cvf "nano-for-windows-g$NfWCommit-x86_64-g$NanoTag-$NanoCommit.tar" (ls *).Name .nanorc
zip -r "nano-for-windows-$NfWCommit-x86_64-$NanoDesc.zip" (ls *).Name .nanorc

cd $Origin

Write-Host "`n`nFinished! Release ZIP is available in > nano/pkg/nano-for-windows-$NfWCommit-x86_64-$NanoDesc.zip <`n"

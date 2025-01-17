# List of C files in "libraries" that we provide
STAFF_LIBS = sdl_wrapper test_util
# List of C files in "libraries" that you will write.
# This also defines the order in which the tests are run.
FAF_LIBS = faf_audio faf_cars faf_hud faf_levels faf_objects faf_leaderboard faf_menu faf_strings
STUDENT_LIBS = body collision forces list mathlib polygon scene shape vector window hud $(FAF_LIBS)


EMCC = emcc
EMCC_FLAGS =  -s ALLOW_MEMORY_GROWTH=1 -s INITIAL_MEMORY=655360000 -s USE_SDL=2 -s USE_SDL_GFX=2 -s USE_SDL_IMAGE=2 -s SDL2_IMAGE_FORMATS='["png"]' -s USE_SDL_TTF=2 -s USE_SDL_MIXER=2 -s ASSERTIONS=1 -O3 --preload-file assets  --use-preload-plugins
WASM_STUDENT_OBJS = $(addprefix out/,$(STUDENT_LIBS:=.wasm.o))
out/%.wasm.o: library/%.c # source file may be found in "library"
	$(EMCC) $(EMCC_FLAGS) -c $(CFLAGS) $^ -o $@
out/%.wasm.o: demo/%.c # or "demo"
	$(EMCC) $(EMCC_FLAGS) -c $(CFLAGS) $^ -o $@
out/%.wasm.o: game_src/%.c # or "game_src"
	$(EMCC) $(EMCC_FLAGS) -c $(CFLAGS) $^ -o $@
out/%.wasm.o: tests/%.c # or "tests"
	$(EMCC) $(EMCC_FLAGS) -c $(CFLAGS) $^ -o $@

bin/furious_and_fast.html: out/furious_and_fast.wasm.o out/sdl_wrapper.wasm.o $(WASM_STUDENT_OBJS)
		$(EMCC) $(EMCC_FLAGS) $(CFLAGS) $(LIBS) $^ -o $@



# If we're not on Windows...
ifneq ($(OS), Windows_NT)

# Use clang as the C compiler
CC = clang
# Flags to pass to clang:
# -Iinclude tells clang to look for #include files in the "include" folder
# -Wall turns on all warnings
# -g adds filenames and line numbers to the executable for useful stack traces
# -fno-omit-frame-pointer allows stack traces to be generated
#   (take CS 24 for a full explanation)
# -fsanitize=address enables asan
CFLAGS := -Iinclude $(shell sdl2-config --cflags | sed -e "s/include\/SDL2/include/")
CFLAGS += -I"game_include"
CFLAGS += -Wall -g -fno-omit-frame-pointer #-fsanitize=address -Wno-nullability-completeness
# Compiler flag that links the program with the math library
LIB_MATH = -lm
# Compiler flags that link the program with the math and SDL libraries.
# Note that $(...) substitutes a variable's value, so this line is equivalent to
# LIBS = -lm -lSDL2 -lSDL2_gfx
LIBS = $(LIB_MATH) $(shell sdl2-config --libs) -lSDL2_gfx -lSDL2_image -lSDL2_mixer -lSDL2_ttf

# List of compiled .o files corresponding to STUDENT_LIBS, e.g. "out/vector.o".
# Don't worry about the syntax; it's just adding "out/" to the start
# and ".o" to the end of each value in STUDENT_LIBS.
STUDENT_OBJS = $(addprefix out/,$(STUDENT_LIBS:=.o))
FAF_OBJS = $(addprefix out/,$(FAF_LIBS:=.o))
# List of test suite executables, e.g. "bin/test_suite_vector"
TEST_BINS = $(addprefix bin/test_suite_,$(STUDENT_LIBS))
# All executables (the concatenation of TEST_BINS and DEMO_BINS)
BINS = bin/furious_and_fast # $(TEST_BINS)

# The first Make rule. It is relatively simple:
# "To build 'all', make sure all files in BINS are up to date."
# You can execute this rule by running the command "make all", or just "make".
all: $(BINS)

# Any .o file in "out" is built from the corresponding C file.
# Although .c files can be directly compiled into an executable, first building
# .o files reduces the amount of work needed to rebuild the executable.
# For example, if only list.c was modified since the last build, only list.o
# gets recompiled, and clang reuses the other .o files to build the executable.
#
# "%" means "any string".
# Unlike "all", this target has a build command.
# "$^" is a special variable meaning "the source files"
# and $@ means "the target file", so the command tells clang
# to compile the source C file into the target .o file.
out/%.o: library/%.c # source file may be found in "library"
	$(CC) -c $(CFLAGS) $^ -o $@
out/%.o: game_src/%.c # source file may be found in "game_src"
	$(CC) -c $(CFLAGS) $^ -o $@
out/%.o: tests/%.c # or "tests"
	$(CC) -c $(CFLAGS) $^ -o $@

# Builds bin/bounce by linking the necessary .o files.
# Unlike the out/%.o rule, this uses the LIBS flags and omits the -c flag,
# since it is building a full executable.

bin/furious_and_fast: out/furious_and_fast.o out/sdl_wrapper.o $(STUDENT_OBJS) $(FAF_OBJS)
		$(CC) $(CFLAGS) $(LIBS) $^ -o $@

# Builds the test suite executables from the corresponding test .o file
# and the library .o files. The only difference from the demo build command
# is that it doesn't link the SDL libraries.
bin/test_suite_%: out/test_suite_%.o out/test_util.o $(STUDENT_OBJS)
	$(CC) $(CFLAGS) $(LIBS) $^ -o $@

bin/student_tests: out/student_tests.o out/test_util.o $(STUDENT_OBJS)
	$(CC) $(CFLAGS) $(LIB_MATH) $^ -o $@

# Runs the tests. "$(TEST_BINS)" requires the test executables to be up to date.
# The command is a simple shell script:
# "set -e" configures the shell to exit if any of the tests fail
# "for f in $(TEST_BINS); do ...; done" loops over the test executables,
#    assigning the variable f to each one
# "echo $$f" prints the test suite
# "$$f" runs the test; "$$" escapes the $ character,
#   and "$f" tells the shell to substitute the value of the variable f
# "echo" prints a newline after each test's output, for readability
test: $(TEST_BINS)
	set -e; for f in $(TEST_BINS); do echo $$f; $$f; echo; done

# Removes all compiled files.
# find <dir> is the command to find files in a directory
# ! -name .gitignore tells find to ignore the .gitignore
# -type f only finds files
# -delete deletes all the files found
clean:
	find out/ ! -name .gitignore -type f -delete && \
	find bin/ ! -name .gitignore -type f -delete

# This special rule tells Make that "all", "clean", and "test" are rules
# that don't build a file.
.PHONY: all clean test
# Tells Make not to delete the .o files after the executable is built
.PRECIOUS: out/%.o

# Windows is _special_
# Define a completely separate set of rules, because syntax and shell
else

# Make normally uses sh, which isn't on Windows by default
# Some systems might have it though...
# So, explicitly use cmd (ew)
# I want to rewrite the test and clean portions in Powershell but
# don't have the time now.
SHELL = cmd.exe

# Use MSVC cl.exe as the C compiler
CC = cl.exe

# Flags to pass to cl.exe:
# -I"C:/Users/$(USERNAME)/msvc/include"
#	- include files that would normally be in /usr/include or something
# -Iinclude = -Iinclude
# -Zi = -g (with debug info in a separate file)
# -W3 turns on warnings (W4 is overkill for this class)
# -Oy- = -fno-omit-frame-pointer. May be unnecessary.
# -fsanitize=address = ...
CFLAGS := -I"C:/Users/$(USERNAME)/msvc/include"
CFLAGS += -I"game_include"
CFLAGS += -Iinclude -Zi -W3 -Oy-
# You may want to turn this off for certain types of debugging.
#CFLAGS += -fsanitize=address

# Define _WIN32, telling the programs that they are running on Windows.
CFLAGS += -D_WIN32
# Math constants are not in the standard
CFLAGS += -D_USE_MATH_DEFINES
# Some functions are """unsafe""", like snprintf. We don't care.
CFLAGS += -D_CRT_SECURE_NO_WARNINGS
# Include the full path for the msCompile problem matcher
C_FLAGS += -FC

# Libraries that we are linking against.
# Note that a lot of the base Windows ones are missing - the
# libraries I've distributed are _dynamically linked_, because otherwise,
# we'd need to manually link a lot of crap.
LIBS = SDL2main.lib SDL2.lib SDL2_gfx.lib shell32.lib SDL2_image.lib SDL2_mixer.lib SDL2_ttf.lib

# Tell cl to look for lib files in this folder
LINKEROPTS = -LIBPATH:"C:/Users/$(USERNAME)/msvc/lib"
# If SDL2 is included in a file with main, it takes over main with its own def.
# We need to explicitly indicate the application type.
# NOTE: CONSOLE is single-threaded. Multithreading needs to use WINDOWS.
LINKEROPTS += -SUBSYSTEM:CONSOLE
# WHY IS LNK4098 HAPPENING (no ill effects from brief checks)
LINKEROPTS += -NODEFAULTLIB:msvcrt.lib

# List of compiled .obj files corresponding to STUDENT_LIBS,
# e.g. "out/vector.obj".
# Don't worry about the syntax; it's just adding "out/" to the start
# and ".obj" to the end of each value in STUDENT_LIBS.
STUDENT_OBJS = $(addprefix out/,$(STUDENT_LIBS:=.obj))
FAF_OBJS = $(addprefix out/,$(FAF_LIBS:=.obj))
# List of test suite executables, e.g. "bin/test_suite_vector.exe"
TEST_BINS = $(addsuffix .exe,$(addprefix bin/test_suite_,$(STUDENT_LIBS)))
# All executables (the concatenation of TEST_BINS and DEMO_BINS)
BINS = $(TEST_BINS) bin/furious_and_fast

# The first Make rule. It is relatively simple:
# "To build 'all', make sure all files in BINS are up to date."
# You can execute this rule by running the command "make all", or just "make".
all: $(BINS)

# Any .o file in "out" is built from the corresponding C file.
# Although .c files can be directly compiled into an executable, first building
# .o files reduces the amount of work needed to rebuild the executable.
# For example, if only list.c was modified since the last build, only list.o
# gets recompiled, and clang reuses the other .o files to build the executable.
#
# "%" means "any string".
# Unlike "all", this target has a build command.
# "$^" is a special variable meaning "the source files"
# and $@ means "the target file", so the command tells clang
# to compile the source C file into the target .obj file. (via -Fo)
out/%.obj: library/%.c # source file may be found in "library"
	$(CC) -c $^ $(CFLAGS) -Fo"$@"
out/%.obj: game_src/%.c
	$(CC) -c $^ $(CFLAGS) -Fo"$@"
out/%.obj: tests/%.c # or "tests"
	$(CC) -c $^ $(CFLAGS) -Fo"$@"

bin/furious_and_fast.exe: out/furious_and_fast.obj out/sdl_wrapper.obj $(STUDENT_OBJS) $(FAF_OBJS)
	$(CC) $^ $(CFLAGS) -link $(LINKEROPTS) $(LIBS) -out:"$@"

# Builds the test suite executables from the corresponding test .o file
# and the library .o files. The only difference from the demo build command
# is that it doesn't link the SDL libraries.
bin/test_suite_%.exe bin\test_suite_%.exe: out/test_suite_%.obj out/test_util.obj $(STUDENT_OBJS)
	$(CC) $^ $(CFLAGS) -link $(LINKEROPTS) $(LIBS) -out:"$@"

# Empty recipes for cross-OS task compatibility.
bin/furious_and_fast bin\furious_and_fast: bin/furious_and_fast.exe ;
bin/test_suite_% bin\test_suite_%: bin/test_suite_%.exe ;

# CMD commands to test and clean

bin/student_tests.exe: out/student_tests.obj out/test_util.obj $(STUDENT_OBJS)
	$(CC) $(CFLAGS) $(LIB_MATH) $^ -o $@

# "$(subst /,\, $(TEST_BINS))" replaces "/" with "\" for
#	Windows paths,
# "echo %%i.exe" prints the test suite,
# "cmd /c %%i.exe" runs the test,
# "|| exit /b" causes the session to exit if any of the tests fail,
# "echo." prints a newline.
test: $(TEST_BINS)
	for %%i in ($(subst /,\, $(TEST_BINS))) \
	do ((echo %%i) && ((cmd /c %%i) || exit /b) && (echo.))

# Explicitly iterate on files in out\* and bin\*, and
# delete if it's not .gitignore
clean:
	for %%i in (out\* bin\*) \
	do (if not "%%~xi" == ".gitignore" del %%~i)

# This special rule tells Make that "all", "clean", and "test" are rules
# that don't build a file.
.PHONY: all clean test
# Tells Make not to delete the .obj files after the executable is built
.PRECIOUS: out/%.obj

endif

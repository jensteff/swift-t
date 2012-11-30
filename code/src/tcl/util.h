
/**
 * TCL/UTIL
 *
 * Various utilities for C-based Tcl extensions
 * */

#ifndef TURBINE_TCL_UTIL_H
#define TURBINE_TCL_UTIL_H

#include <tcl.h>

#include "src/turbine/turbine.h"

#define EMPTY_FLAG 0

/**
   Check that the user gave us the correct number of arguments
   objc should be equal to count.  If not, fail.
   Note that in Tcl, the command name counts as an argument
*/
#define TCL_ARGS(count) {                                       \
    if (objc != count) {                                        \
      char* tmp = Tcl_GetStringFromObj(objv[0], NULL);          \
      printf("command %s requires %i arguments, received %i\n", \
             tmp, count, objc);                                 \
      return TCL_ERROR;                                         \
    }                                                           \
  }

/**
   Check that the user gave us the correct number of arguments
   for this subcommand
   objc should be equal to count.  If not, fail.
   Note that in Tcl, the command name counts as an argument
   For example, for command "string length s":
            command=string, objv[0]=length, objv[1]=s, count=2
*/
#define TCL_ARGS_SUB(command, count) {                                       \
    if (objc != count) {                                        \
      char* tmp = Tcl_GetStringFromObj(objv[0], NULL);          \
      printf("command " #command                                \
             " %s requires %i arguments, received %i\n",        \
             tmp, count, objc);                                 \
      return TCL_ERROR;                                         \
    }                                                           \
  }

turbine_code turbine_tcl_long_array(Tcl_Interp* interp,
                                    Tcl_Obj* list, int max,
                                    long* output, int* count);

turbine_code turbine_tcl_string_array(Tcl_Interp* interp,
                                      Tcl_Obj* list, int max,
                                      char** output, int* count);

void tcl_condition_failed(Tcl_Interp* interp, Tcl_Obj* command,
                          const char* format, ...)
  __attribute__ ((format (printf, 3, 4)));


void tcl_set_integer(Tcl_Interp* interp, char* name, int value);

void tcl_set_long(Tcl_Interp* interp, char* name, long value);

void tcl_dict_put(Tcl_Interp* interp, Tcl_Obj* dict,
                  char* key, Tcl_Obj* value);

/*
   Tcl check follow.  Note that these are disabled by NDEBUG.
   Thus, they should never do anything in a correct Turbine program.
 */
#ifndef NDEBUG

#define TCL_CHECK(rc) { if (rc != TCL_OK) { return TCL_ERROR; }}

/**
   Print error message and return a Tcl error
   Disabled by NDEBUG
 */
#define TCL_RETURN_ERROR(format, args...)                        \
  {                                                              \
    tcl_condition_failed(interp, objv[0], format, ## args);      \
    return TCL_ERROR;                                            \
  }

/**
   If rc is not TCL_OK, return a Tcl error
   Disabled by NDEBUG
 */
#define TCL_CHECK_MSG(rc, format, args...)                        \
  if (rc != TCL_OK) {                                             \
    TCL_RETURN_ERROR(format, ## args);                            \
  }

/**
   If condition is false, return a Tcl error
   Disabled by NDEBUG
 */
#define TCL_CONDITION(condition, format, args...)                \
  if (!(condition)) {                                            \
    TCL_RETURN_ERROR(format, ## args);                           \
  }

#else

#define TCL_CHECK(rc) ((void)(rc))
#define TCL_RETURN_ERROR(format, args...)
#define TCL_CHECK_MSG(rc, format, args...) ((void)(rc))
#define TCL_CONDITION(condition, format, args...) ((void)(condition))

#endif

#endif

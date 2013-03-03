# Edebug-X -- Extensions for Edebug

Extensions to Edebug to make it a little nicer to work with. Provides highlighting for breakpoints, instrumented functions
and current line of debugger. Also provides a couple of commands to list current breakpoints and instrumented functions.

![Edebug-x highlights](https://raw.github.com/ScottyB/edebug-x/master/images/edebug-highlights.png)

This package provides the following functions:
```
edebug-x-modify-breakpoint-wrapper     - toggle breakpoints in Elisp buffer, C-x SPC
                                         When called with a prefix argument a conditional breakpoint is set
edebug-x-show-breakpoints              - show a tabulated list of all breakpoints, C-c C-x b
edebug-x-show-instrumented             - show a tabulated list of instrumented functions, C-c C-x i
edebug-x-show-data                     - show both the breakpoints and instrumented functions buffer, C-c C-x s
```

From the tabulated list buffer the following commands are available:
```
edebug-x-kill-breakpoint               - bound to K, clear breakpoint
edebug-x-visit-breakpoint              - bound to RET, visit breakpoint location
```

The instrumented functions buffer has these commands:
```
edebug-x-evaluate-function             - bound to E, evaluate function, clearing breakpoints within it
edebug-x-find-function bound to        - bound to RET, jump to function
```

Executing Q after `edebug-x-show-data` will remove both buffers and remove the split.

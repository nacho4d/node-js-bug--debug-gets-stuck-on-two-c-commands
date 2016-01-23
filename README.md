Example code to a bug with the node.js debugger.
It was verified to be present with node-v5.4.0 built from source on Mageia Linux x86 v6 (Cauldron). Also in node 5.5.0 in Mac OS X

To reproduce run something like:

    node debug perlito5.js

Originally taken from [shlomif/node-js-bug--debug-gets-stuck-on-two-c-commands](https://github.com/shlomif/node-js-bug--debug-gets-stuck-on-two-c-commands) 

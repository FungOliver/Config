set pagination off
set follow-fork-mode child
catch fork
catch exec

set output-radix 16

python

try:
    gdb.execute('set disassembly-flavor intel')
except Exception:
    # On non-x86 architectures, this doesn't work.
    pass

archs = [
    {
        "name": "i386:x86-64", "long": True,
        "regs": "rdi rsi rdx rcx rax rbx rbp rsp".split() + ["r"+str(i) for i in range(8, 16)],
    }, {
        "name": "i386",
        "regs": "edi esi edx ecx eax ebx ebp esp".split(),
    }, {
        "name": "arm",
        "regs": ["r"+str(i) for i in range(11)] + "fp ip sp lr pc".split(),
    }, {
        "name": "aarch64", "long": True,
        "regs": ["x"+str(i) for i in range(31)] + ["sp"],
    }
]
regsFmt = {}
isLong = {arch["name"]: "long" in arch for arch in archs}
for arch in archs:
    fmt = ["{:>3}: %{}lx".format(r, 16 if "long" in arch else 8) for r in arch["regs"]]
    fmt = "".join([" ".join(fmt[i:i+4]) + "\\n" for i in range(0, len(fmt), 4)])
    regsFmt[arch["name"]] = 'printf "{0}\\n", {1}'.format(fmt, ",".join(["$"+r for r in arch["regs"]]))


def py_stop_hook():
    try:
        arch = gdb.selected_frame().architecture().name()
        if arch not in isLong: return

        gdb.write('\n\033[92m')
        try:
            gdb.execute('x/5i $pc')
        except Exception:
            gdb.execute('printf "Could not parse instructions at %#lx", $pc\n')
        gdb.write('\033[0m\n')

        gdb.execute(regsFmt[arch])

        try:
            if isLong[arch]:
                stackFormat = 'printf "\033[2m%#lx:\033[0m %#018lx %#018lx %#018lx %#018lx\\n", $sp+8*{0}, *((long*)$sp + {0}), *((long*)$sp + {1}), *((long*)$sp + {2}), *((long*)$sp + {3})'
            else:
                stackFormat = 'printf "\033[2m%#lx:\033[0m %#010lx %#010lx %#010lx %#010lx\\n", $sp+4*{0}, *((int*)$sp + {0}), *((int*)$sp + {1}), *((int*)$sp + {2}), *((int*)$sp + {3})'
            for i in range(4):
                gdb.execute(stackFormat.format(i*4, i*4+1, i*4+2, i*4+3))
        except Exception:
            gdb.execute('printf "Could not read stack at %#lx", $sp\n')
            pass
        gdb.write('\033[0m\n')
    except Exception:
        pass
end

define hook-stop
    python py_stop_hook()
end


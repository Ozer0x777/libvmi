import sys
p=sys.argv[1]+"/libvmi/os/windows/core.c"
s=open(p).read()
a="    if (VMI_FAILURE == init_core(vmi))\n        goto done;\n"
assert a in s
s=s.replace(a,"    if (getenv(\"KPGD_POISON\")) { vmi->kpgd = strtoull(getenv(\"KPGD_POISON\"), NULL, 16); }\n"+a,1)
open(p,"w").write(s)

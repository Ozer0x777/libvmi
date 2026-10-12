# unattend for Server 2008 R2 SP1 / 2012 RTM / 2008 SP2 (retail/VL media: a KMS client setup key is needed), Administrator only,
# modelled on the 2012 R2 "adm" variant (no HideOEM/HideOnlineAccount elements, which Win7/8-era setups may reject)
import os, re, subprocess
base = open("/root/au-78/winsrv2012r2adm/autounattend.xml").read()
assert "ProductKey" not in base
def variant(name, key):
    s = base.replace("<Value>Windows Server 2012 R2 SERVERSTANDARD</Value>", "<Value>%s</Value>" % name)
    s = s.replace("<AcceptEula>true</AcceptEula>", "<AcceptEula>true</AcceptEula>\n                <ProductKey>\n                    <Key>%s</Key>\n                    <WillShowUI>Never</WillShowUI>\n                </ProductKey>" % key)
    assert name in s and key in s
    return s
V = {"winsrv2008r2adm": variant("Windows Server 2008 R2 SERVERSTANDARD", "YC6KT-GKW9T-YTKYR-T4X34-R7VHC"),
     "winsrv2012adm":   variant("Windows Server 2012 SERVERSTANDARD",    "XC9B7-NBPP2-83J2H-RHMBY-92BT4"),
     "winsrv2008adm":   variant("Windows Longhorn SERVERSTANDARD",       "TM24T-X9RMF-VWXK6-X8JC9-BFGM2")}
for tag, x in V.items():
    d = "/root/au-78/%s" % tag; os.makedirs(d, exist_ok=True); open(d + "/autounattend.xml", "w").write(x)
    out = "/root/iso/autounattend-%s.iso" % tag
    subprocess.run(["xorriso", "-as", "mkisofs", "-o", out, "-J", "-r", "-V", "UNATTEND", d], capture_output=True); print(tag, os.path.getsize(out))

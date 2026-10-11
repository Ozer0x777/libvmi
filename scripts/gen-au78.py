# autounattend variants for Windows 7 / 8 / 8.1 from the Windows 10 x86 one (/root/au-x86/en/autounattend.xml)
import re, os, subprocess
base = open("/root/au-x86/en/autounattend.xml").read()
assert base.count('processorArchitecture="x86"') == 6
# public KMS client setup keys (install only, no activation)
V = {
 "win7-x86":  dict(arch="x86",   key="FJ82H-XT6CR-J8D7P-XQJJ2-GPDD4", name="Windows 7 ULTIMATE", win7=True),
 "win7-x64":  dict(arch="amd64", key="FJ82H-XT6CR-J8D7P-XQJJ2-GPDD4", name="Windows 7 ULTIMATE", win7=True),
 "win8-x86":  dict(arch="x86",   key="32JNW-9KQ84-P47T8-D8GGY-CWCK7", name=None, win7=False),   # Enterprise media
 "win8-x64":  dict(arch="amd64", key="NG4HW-VH26C-733KW-K6F98-J8CK4", name=None, win7=False),   # Pro
 "win81-x86": dict(arch="x86",   key="GCRJD-8NW9H-F2CDX-CCM8D-9D6T9", name=None, win7=False),   # Pro
 "win81-x64": dict(arch="amd64", key="GCRJD-8NW9H-F2CDX-CCM8D-9D6T9", name=None, win7=False),
}
for tag, v in V.items():
    s = base.replace('processorArchitecture="x86"', 'processorArchitecture="%s"' % v["arch"])
    s = s.replace("<Key></Key>", "<Key>%s</Key>" % v["key"])
    # no Defender cmdlets before Windows 10
    s = re.sub(r'\s*<SynchronousCommand wcm:action="add">\s*<Order>1</Order>.*?</SynchronousCommand>', "", s, flags=re.S)
    s = s.replace("<HideOEMRegistrationScreen>true</HideOEMRegistrationScreen>\n", "")
    if v["win7"]:
        s = s.replace("<HideOnlineAccountScreens>true</HideOnlineAccountScreens>\n", "")
        s = s.replace("<Key>/IMAGE/INDEX</Key>\n                            <Value>1</Value>",
                      "<Key>/IMAGE/NAME</Key>\n                            <Value>%s</Value>" % v["name"])
        assert "/IMAGE/NAME" in s
    d = "/root/au-78/%s" % tag; os.makedirs(d, exist_ok=True)
    open(d + "/autounattend.xml", "w").write(s)
    out = "/root/iso/autounattend-%s.iso" % tag
    subprocess.run(["xorriso", "-as", "mkisofs", "-o", out, "-J", "-r", "-V", "UNATTEND", d], capture_output=True)
    print(tag, "arch=%d" % s.count('processorArchitecture="%s"' % v["arch"]), "key" , v["key"][:5], "OEMreg" , "HideOEMRegistrationScreen" in s, "online", "HideOnlineAccountScreens" in s, "mp", "Set-MpPreference" in s, os.path.getsize(out))

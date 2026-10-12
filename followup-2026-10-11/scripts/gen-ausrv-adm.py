# Server unattend "adm" variants modelled on the Server 2019 DC file that worked: Administrator only (no extra local account),
# Organization set, image by NAME, no ProductKey, no Defender cmdlet
import re, os, subprocess
base = open("/root/au-78/winsrv/autounattend.xml").read()
def variant(name, drop_oobe):
    s = base.replace("<Key>/IMAGE/INDEX</Key>\n                            <Value>2</Value>", "<Key>/IMAGE/NAME</Key>\n                            <Value>%s</Value>" % name)
    s = s.replace("<FullName>Analyst</FullName>", "<FullName>Administrator</FullName>").replace("<Organization></Organization>", "<Organization>Lab</Organization>")
    s = re.sub(r"\s*<LocalAccounts>.*?</LocalAccounts>", "", s, flags=re.S)
    s = s.replace("<Username>analyst</Username>", "<Username>Administrator</Username>")
    if drop_oobe:
        s = s.replace("<HideOEMRegistrationScreen>true</HideOEMRegistrationScreen>\n", "").replace("<HideOnlineAccountScreens>true</HideOnlineAccountScreens>\n", "")
    assert "/IMAGE/NAME" in s and "LocalAccounts" not in s and "ProductKey" not in s and "AdministratorPassword" in s
    return s
V = {"winsrv2012r2adm": variant("Windows Server 2012 R2 SERVERSTANDARD", True),
     "winsrv2016adm": variant("Windows Server 2016 SERVERSTANDARD", False),
     "winsrv2019adm": variant("Windows Server 2019 SERVERSTANDARD", False),
     "winsrv2022adm": variant("Windows Server 2022 SERVERSTANDARD", False),
     "winsrv2025adm": variant("Windows Server 2025 SERVERSTANDARD", False)}
for tag, x in V.items():
    d = "/root/au-78/%s" % tag; os.makedirs(d, exist_ok=True); open(d + "/autounattend.xml", "w").write(x)
    out = "/root/iso/autounattend-%s.iso" % tag
    subprocess.run(["xorriso", "-as", "mkisofs", "-o", out, "-J", "-r", "-V", "UNATTEND", d], capture_output=True); print(tag, os.path.getsize(out))

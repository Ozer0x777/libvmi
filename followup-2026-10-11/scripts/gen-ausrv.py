# autounattend for the Windows Server test VMs, from the Windows 10 x86 one: amd64, Standard (Desktop Experience) = index 2,
# NO ProductKey element (evaluation media refuse it), Administrator password set, no Defender cmdlet
import re, os, subprocess
base = open("/root/au-x86/en/autounattend.xml").read()
s = base.replace('processorArchitecture="x86"', 'processorArchitecture="amd64"')
s = re.sub(r'\s*<ProductKey>.*?</ProductKey>', "", s, flags=re.S)
s = s.replace("<Key>/IMAGE/INDEX</Key>\n                            <Value>1</Value>", "<Key>/IMAGE/INDEX</Key>\n                            <Value>2</Value>")
s = re.sub(r'\s*<SynchronousCommand wcm:action="add">\s*<Order>1</Order>.*?</SynchronousCommand>', "", s, flags=re.S)
s = s.replace("<UserAccounts>\n", "<UserAccounts>\n                <AdministratorPassword>\n                    <Value>Analyst123!</Value>\n                    <PlainText>true</PlainText>\n                </AdministratorPassword>\n")
assert "ProductKey" not in s and "<Value>2</Value>" in s and "AdministratorPassword" in s
V = {"winsrv": s, "winsrv2012r2": s.replace("<HideOEMRegistrationScreen>true</HideOEMRegistrationScreen>\n", "").replace("<HideOnlineAccountScreens>true</HideOnlineAccountScreens>\n", "")}
for tag, x in V.items():
    d = "/root/au-78/%s" % tag; os.makedirs(d, exist_ok=True); open(d + "/autounattend.xml", "w").write(x)
    out = "/root/iso/autounattend-%s.iso" % tag
    subprocess.run(["xorriso", "-as", "mkisofs", "-o", out, "-J", "-r", "-V", "UNATTEND", d], capture_output=True)
    print(tag, os.path.getsize(out), "amd64=%d" % x.count('amd64'), "mp" , "Set-MpPreference" in x)

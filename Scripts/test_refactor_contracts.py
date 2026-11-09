#!/usr/bin/env python3
"""Compile and exercise actual Foundation/model code with the checked-in ObjectMapper dependency.
No service requests, account actions, application launch, or runtime permission changes.
"""
from pathlib import Path
import subprocess,tempfile

root=Path(__file__).resolve().parents[1]
app=root/'FlexRupee'
def run(args):
    proc=subprocess.run(args,cwd=root,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
    if proc.returncode:
        print(proc.stdout)
        raise SystemExit(proc.returncode)
    return proc.stdout
with tempfile.TemporaryDirectory(prefix='flexrupee-contracts-') as temp:
    scratch=Path(temp)
    sources=sorted((root/'Pods/ObjectMapper/Sources').glob('*.swift'))
    if not sources:raise SystemExit('ObjectMapper sources missing; restore locked project dependencies first')
    run(['xcrun','swiftc','-swift-version','5','-suppress-warnings','-emit-library','-emit-module','-module-name','ObjectMapper',*[str(p) for p in sources],'-emit-module-path',str(scratch/'ObjectMapper.swiftmodule'),'-o',str(scratch/'libObjectMapper.dylib')])
    # These exact enum declarations are extracted only to avoid importing UIKit into the macOS harness.
    bubble=(app/'Shared/Widgets/FlexFieldHintBubble.swift').read_text()
    enums=bubble[bubble.index('enum FlexFieldHintKind'):bubble.index('enum FlexFieldHintBubble')]
    hub=(app/'Modules/Hub/Pilot/MintHubPilot.swift').read_text()
    hub=hub[hub.index('enum HubMemberPhase'):hub.index('final class MintHubPilot')]
    support=scratch/'UIIndependentDeclarations.swift';support.write_text('import Foundation\n'+enums+'\n'+hub)
    binary=scratch/'contracts'
    run(['xcrun','swiftc','-swift-version','5','-I',str(scratch),'-L',str(scratch),'-lObjectMapper','-Xlinker','-rpath','-Xlinker',str(scratch),str(support),str(app/'Core/Validation/RupeeAmountFormat.swift'),str(app/'Core/Theme/FlexPhraseBook.swift'),str(app/'Core/Network/WireShards.swift'),str(root/'Scripts/Tests/RefactorContracts.swift'),'-o',str(binary)])
    print(run([str(binary)]),end='')

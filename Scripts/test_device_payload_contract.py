#!/usr/bin/env python3
"""Exercise the production payload assembler with deterministic probes; no device data is uploaded."""
import argparse,json,re,subprocess,tempfile
from pathlib import Path
root=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--reference',type=Path,required=True,help='WiseEngineer project directory')
a=p.parse_args()
reference=(a.reference/'WiseEngineer/Util/WEDevicewe.m').read_text()
keys=set(re.findall(r'we_params\[@"([^\"]+)"\]',reference))
source=(root/'FlexRupee/Core/Device/RupeeDeviceProbe.swift').read_text().replace('import UIKit','import Foundation')
stubs='''
class UIDevice { static let current = UIDevice(); let name = "fixture-phone"; let systemVersion = "18.0" }
enum RupeeDeviceConstants { static let nullToken = "null" }
enum RupeeDeviceIdentityProbe {
 static func stableUUID()->String { "fixture-id" }
 static func idfv()->String { "fixture-idfv" }
 static func idfaOrNull()->String { "null" }
}
enum RupeeDeviceHardwareProbe {
 struct Screen { let pixelWidth = 1170.0; let pixelHeight = 2532.0; let pointWidth = 390.0; let pointHeight = 844.0; let brightnessPercent = 50 }
 static func screenMetrics()->Screen { Screen() }
 static func appVersionShortString()->String { "1.0" }
 static func hardwareModelIdentifier()->String { "fixture-model" }
 static func deviceModelName()->String { "fixture-model-name" }
 static func elapsedSinceBootMs()->Int64 { 20000 }
 static func bootTimeMs()->Int64 { 19000 }
 static func lastBootTimeMs()->Int64 { 100000 }
 static func hasSystemModificationIndicators()->Bool { false }
 static func isBeingDebugged()->Bool { true }
 static let isSimulator = true
}
enum RupeeDeviceNetworkProbe {
 struct Tel { let primary = "unused"; let secondary = "null"; let slotCount = "1"; let simCount = "0" }
 static var ssid:String? = "fixture-wifi"
 static var bssid:String? = "fixture-bssid"
 static func currentWiFiInfo()->(String?,String?) { (ssid,bssid) }
 static func refreshWiFiCache(completion:()->Void) { completion() }
 static func telephonyOperators()->Tel { Tel() }
 static func networkCategory()->String { "-99" }
 static func isSystemProxyEnabled()->Bool { false }
 static func isVPNOn()->Bool { false }
}
enum RupeeDevicePowerProbe {
 static func batteryLevelPercent()->String { "71.5" }
 static func isCharging()->Bool { true }
}
enum RupeeDeviceStorageProbe {
 static func ramCanUseGBString()->String { "2.500000" }
 static func ramTotalGBString()->String { "8.000000" }
 static func diskFreeGBString()->String { "10.000000" }
 static func diskTotalGBString()->String { "128.000000" }
}
enum RupeeDeviceLocaleProbe {
 static func defaultLanguage()->String { "en" }
 static func defaultTimeZone()->String { "Asia/Kolkata" }
}
'''
main='''
func write(_ value:[String:Any]) { let data = try! JSONSerialization.data(withJSONObject:value,options:[.sortedKeys]);print(String(data:data,encoding:.utf8)!) }
write(RupeeDeviceProbe.shared.syncPayload())
RupeeDeviceNetworkProbe.ssid = nil;RupeeDeviceNetworkProbe.bssid = nil
RupeeDeviceProbe.shared.buildSyncPayload { write($0) }
RupeeDeviceNetworkProbe.ssid = "0"
write(RupeeDeviceProbe.shared.syncPayload())
'''
with tempfile.TemporaryDirectory() as tmp:
 path=Path(tmp);(path/'main.swift').write_text(stubs+'\n'+source+'\n'+main)
 subprocess.run(['xcrun','swiftc',str(path/'main.swift'),'-o',str(path/'test')],check=True,capture_output=True,text=True)
 run=subprocess.run([str(path/'test')],check=True,capture_output=True,text=True)
 payloads=[json.loads(line) for line in run.stdout.splitlines()]
 for payload in payloads:
  assert set(payload)==keys, {'missing':sorted(keys-set(payload)),'extra':sorted(set(payload)-keys)}
  assert all(isinstance(v,str) for v in payload.values()),'device values must be strings'
  assert 'orderId' not in payload and 'telephony' not in payload
  assert payload['cpuNum'].isdigit() and payload['deviceType']=='3'
  assert payload['batteryLevel']=='71.5'
  assert payload['totalBootTime']=='20000' and payload['totalBootTimeWake']=='19000'
  assert payload['simulated']=='true' and payload['debugged']=='true'
  assert payload['screenResolution']=='1170-2532' and payload['ramCanUse']=='2.500000'
 assert payloads[1]['wifiSsid']==payloads[1]['wifiBssid']==payloads[1]['mac']=='null'
 assert payloads[2]['wifiSsid']=='0'
 print(f'Passed production assembler contract: {len(keys)} reference fields, 3 deterministic scenarios; no live telemetry or API calls.')

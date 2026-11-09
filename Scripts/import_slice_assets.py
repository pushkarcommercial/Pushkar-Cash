#!/usr/bin/env python3
"""Import AI-IN32-DC_slices into FlexRupee/Assets.xcassets (imagesets)."""

from __future__ import annotations

import json
import re
import shutil
from pathlib import Path

SOURCE = Path("/Users/spirit/Desktop/AI-IN32-DC_slices")
ASSETS = Path("/Users/spirit/Desktop/FlexRupee/FlexRupee/Assets.xcassets")

# Old stem -> new themed stem (rupeeArt_* vocabulary: nature + flex finance, varied compounds)
STEM_MAP: dict[str, str] = {
    "wyglsst_about_logo": "rupeeArt_brandCedarSeal",
    "wyglsst_bank_bg": "rupeeArt_vaultHarborPlume",
    "wyglsst_bank_edit": "rupeeArt_vaultEditHook",
    "wyglsst_bank_kzt": "rupeeArt_vaultEmptyHaze",
    "wyglsst_contact_email": "rupeeArt_supportMailGem",
    "wyglsst_contact_website": "rupeeArt_supportWebLatch",
    "wyglsst_copy": "rupeeArt_clipboardTwine",
    "wyglsst_dly_dx_n": "rupeeArt_agreeMossIdle",
    "wyglsst_dly_dx_u": "rupeeArt_agreeSageMarked",
    "wyglsst_dly_logo": "rupeeArt_gateBloomSigil",
    "wyglsst_dly_otp": "rupeeArt_otpCipherShard",
    "wyglsst_dly_sjh": "rupeeArt_phoneReedGlyph",
    "wyglsst_emi_n": "rupeeArt_dockCalcRest",
    "wyglsst_emi_u": "rupeeArt_dockCalcBeam",
    "wyglsst_feedback_delete": "rupeeArt_feedbackRemoveCoil",
    "wyglsst_feedback_upload": "rupeeArt_feedbackUploadPod",
    "wyglsst_findsisc_xl": "rupeeArt_ifscSearchMark",
    "wyglsst_fj": "rupeeArt_navBackPlate",
    "wyglsst_home_jt": "rupeeArt_offerChevronTwine",
    "wyglsst_home_kzt": "rupeeArt_hubEmptyMist",
    "wyglsst_home_z": "rupeeArt_hubBannerCoinLeft",
    "wyglsst_home_y": "rupeeArt_hubBannerCoinRight",
    "wyglsst_bfh": "rupeeArt_recommendRejectMist",
    "wyglsst_dhk": "rupeeArt_loanWalletPlume",
    "wyglsst_home_mrqd_bg": "rupeeArt_checkinTapestry",
    "wyglsst_home_n": "rupeeArt_dockSproutIdle",
    "wyglsst_home_u": "rupeeArt_dockSproutLit",
    "wyglsst_jzsj": "rupeeArt_upgradePromptLeaf",
    "wyglsst_kyc_delete": "rupeeArt_kycRemovePin",
    "wyglsst_kyc_fh": "rupeeArt_kycBackHook",
    "wyglsst_kyc_jjlxr": "rupeeArt_kycEmergencyLeaf",
    "wyglsst_kyc_pz": "rupeeArt_kycCameraOrb",
    "wyglsst_kyc_pz_c": "rupeeArt_kycCaptureFrame",
    "wyglsst_kyc_pz_d": "rupeeArt_kycCaptureDone",
    "wyglsst_kyc_rlsb": "rupeeArt_kycFacePrism",
    "wyglsst_loan_bank": "rupeeArt_loanBankChip",
    "wyglsst_loan_js_n": "rupeeArt_termInterestRest",
    "wyglsst_loan_js_u": "rupeeArt_termInterestActive",
    "wyglsst_loan_qxxz": "rupeeArt_termSelectArrow",
    "wyglsst_loan_sm": "rupeeArt_loanInfoSpark",
    "wyglsst_loan_success": "rupeeArt_dealSuccessGlow",
    "wyglsst_loan_zj_n": "rupeeArt_termPrincipalRest",
    "wyglsst_loan_zj_u": "rupeeArt_termPrincipalActive",
    "wyglsst_me_N": "rupeeArt_dockVaultDim",
    "wyglsst_me_about": "rupeeArt_menuAboutSigil",
    "wyglsst_me_bank": "rupeeArt_menuVaultGlyph",
    "wyglsst_me_contact": "rupeeArt_menuRelayIcon",
    "wyglsst_me_gwlj": "rupeeArt_menuWebAnchor",
    "wyglsst_me_hkxz": "rupeeArt_menuRepayWave",
    "wyglsst_me_jktj": "rupeeArt_menuLoanTerms",
    "wyglsst_me_logo": "rupeeArt_avatarCoralRing",
    "wyglsst_me_tcdl": "rupeeArt_menuExitMark",
    "wyglsst_me_u": "rupeeArt_dockVaultBright",
    "wyglsst_me_yjfk": "rupeeArt_menuFeedbackOrb",
    "wyglsst_me_ysxy": "rupeeArt_menuPolicyLeaf",
    "wyglsst_order_cancel": "rupeeArt_statusCancelSlate",
    "wyglsst_order_change": "rupeeArt_statusChangeVine",
    "wyglsst_order_kzt": "rupeeArt_ordersEmptyDrift",
    "wyglsst_order_n": "rupeeArt_dockLedgerMute",
    "wyglsst_order_overdue": "rupeeArt_statusOverdueRose",
    "wyglsst_order_payoff": "rupeeArt_statusPayoffSage",
    "wyglsst_order_pending": "rupeeArt_statusPendingAmber",
    "wyglsst_order_processing": "rupeeArt_statusFlowTeal",
    "wyglsst_order_reject": "rupeeArt_statusRejectClay",
    "wyglsst_order_review": "rupeeArt_statusReviewPearl",
    "wyglsst_order_u": "rupeeArt_dockLedgerGlow",
    "wyglsst_order_unfinished": "rupeeArt_statusDraftMist",
    "wyglsst_order_weithdrawn": "rupeeArt_statusWithdrawBloom",
    "wyglsst_pzk": "rupeeArt_kycCardTemplate",
    "wyglsst_qdy_bg": "rupeeArt_splashNightHarbor",
    "wyglsst_qdy_logo": "rupeeArt_splashDawnCrest",
    "wyglsst_tk_cg": "rupeeArt_dialogSuccessCrest",
    "wyglsst_tk_cwts1": "rupeeArt_dialogErrorStepOne",
    "wyglsst_tk_cwts2": "rupeeArt_dialogErrorStepTwo",
    "wyglsst_tk_cwts3": "rupeeArt_dialogErrorStepThree",
    "wyglsst_tk_dtx": "rupeeArt_dialogWithdrawArt",
    "wyglsst_tk_fh": "rupeeArt_dialogBackGlyph",
    "wyglsst_tk_gb": "rupeeArt_dialogCloseMark",
    "wyglsst_tk_gx": "rupeeArt_dialogUpgradeBanner",
    "wyglsst_tk_hpyd_df": "rupeeArt_dialogRatingBackdrop",
    "wyglsst_tk_hpyd_n": "rupeeArt_dialogStarRest",
    "wyglsst_tk_hpyd_u": "rupeeArt_dialogStarLit",
    "wyglsst_tk_sb": "rupeeArt_dialogFailSeal",
    "wyglsst_tk_sczh": "rupeeArt_dialogDeleteAccount",
    "wyglsst_tk_tcdl": "rupeeArt_dialogSignOut",
    "wyglsst_tk_ts": "rupeeArt_dialogThanksPlume",
    "wyglsst_tk_txl": "rupeeArt_dialogContactsArt",
    "wyglsst_tk_tz": "rupeeArt_dialogNotifyArt",
    "wyglsst_tk_xj": "rupeeArt_dialogCameraArt",
    "wyglsst_tk_xl": "rupeeArt_dialogChevronDown",
    "wyglsst_tk_xz": "rupeeArt_dialogCheckboxRest",
    "wyglsst_xl": "rupeeArt_rowChevronTwine",
}

FILE_PATTERN = re.compile(r"^(?P<stem>.+)@(?P<scale>[23])x(?:\(\d+\))?\.png$")

KYC_BACK_INK = (0x1A, 0x1A, 0x1A)
KYC_BACK_CHEVRON_THR = 100
KYC_BACK_PLATE_THR = 8


def write_imageset(stem: str, files_by_scale: dict[str, Path]) -> None:
    folder = ASSETS / f"{stem}.imageset"
    folder.mkdir(parents=True, exist_ok=True)
    images: list[dict] = [{"idiom": "universal", "scale": "1x"}]
    for scale in sorted(files_by_scale.keys()):
        src = files_by_scale[scale]
        dest_name = f"{stem}@{scale}x.png"
        if src.resolve() != (folder / dest_name).resolve():
            shutil.copy2(src, folder / dest_name)
        images.append({"filename": dest_name, "idiom": "universal", "scale": f"{scale}x"})
    (folder / "Contents.json").write_text(
        json.dumps({"images": images, "info": {"author": "xcode", "version": 1}}, indent=2) + "\n",
        encoding="utf-8",
    )


def bake_kyc_back_for_light_nav(src: Path, dest: Path) -> None:
    try:
        from PIL import Image
    except ImportError as exc:
        raise SystemExit("Pillow required to bake wyglsst_kyc_fh: pip install Pillow") from exc

    im = Image.open(src).convert("RGBA")
    out = Image.new("RGBA", im.size, (0, 0, 0, 0))
    sp, op = im.load(), out.load()
    assert sp is not None and op is not None
    for y in range(im.size[1]):
        for x in range(im.size[0]):
            alpha = sp[x, y][3]
            if alpha >= KYC_BACK_CHEVRON_THR:
                op[x, y] = (255, 255, 255, 255)
            elif alpha >= KYC_BACK_PLATE_THR:
                boosted = min(255, max(200, alpha * 7))
                op[x, y] = (*KYC_BACK_INK, boosted)
    out.save(dest)


def old_stem_from_filename(name: str) -> str | None:
    match = FILE_PATTERN.match(name)
    if not match:
        return None
    stem = match.group("stem")
    stem = re.sub(r"\(\d+\)$", "", stem)
    return stem


def swift_catalog(entries: list[tuple[str, str, str]]) -> str:
    lines = [
        "import Foundation",
        "",
        "/// Themed slice asset keys (`rupeeArt_*`). Source stems mapped in Scripts/import_slice_assets.py.",
        "enum FlexSliceCatalog {",
    ]
    for const_name_value, new_stem, _old in entries:
        lines.append(f'    static let {const_name_value} = "{new_stem}"')
    lines.append("}")
    lines.append("")
    return "\n".join(lines)


def const_name(old_stem: str, new_stem: str) -> str:
    suffix = new_stem.removeprefix("rupeeArt_")
    parts = re.findall(r"[A-Z]?[a-z]+|[A-Z]+(?=[A-Z]|$)|\d+", suffix)
    if not parts:
        parts = [suffix]
    return parts[0].lower() + "".join(p.capitalize() for p in parts[1:])


def main() -> None:
    if not SOURCE.is_dir():
        raise SystemExit(f"Missing source folder: {SOURCE}")

    ASSETS.mkdir(parents=True, exist_ok=True)
    tmp = ASSETS / ".import_tmp"
    tmp.mkdir(exist_ok=True)

    copied = 0
    seen_targets: set[str] = set()
    catalog_entries: list[tuple[str, str, str]] = []
    pending: dict[str, dict[str, Path]] = {}

    for src_file in sorted(SOURCE.iterdir()):
        if src_file.suffix != ".png":
            continue
        old_stem = old_stem_from_filename(src_file.name)
        if not old_stem:
            continue
        new_stem = STEM_MAP.get(old_stem)
        if not new_stem:
            print(f"WARN: no mapping for {old_stem} ({src_file.name})")
            continue

        match = FILE_PATTERN.match(src_file.name)
        scale = match.group("scale") if match else "3"
        key = f"{new_stem}@{scale}"
        is_numbered_dup = bool(re.search(r"@\dx\(\d+\)\.png$", src_file.name))
        if key in seen_targets:
            if old_stem == "wyglsst_kyc_pz" and is_numbered_dup:
                pass
            else:
                continue

        dest_tmp = tmp / f"{new_stem}@{scale}x.png"
        if old_stem == "wyglsst_kyc_fh":
            bake_kyc_back_for_light_nav(src_file, dest_tmp)
        else:
            shutil.copy2(src_file, dest_tmp)
        pending.setdefault(new_stem, {})[scale] = dest_tmp
        seen_targets.add(key)
        copied += 1

        if not any(e[1] == new_stem for e in catalog_entries):
            catalog_entries.append((const_name(old_stem, new_stem), new_stem, old_stem))

    for scale in ("2", "3"):
        shutter_src = SOURCE / f"wyglsst_kyc_pz@{scale}x.png"
        if shutter_src.is_file():
            dest_tmp = tmp / f"rupeeArt_kycShutterDisc@{scale}x.png"
            shutil.copy2(shutter_src, dest_tmp)
            pending.setdefault("rupeeArt_kycShutterDisc", {})[scale] = dest_tmp
            copied += 1
    if not any(e[1] == "rupeeArt_kycShutterDisc" for e in catalog_entries):
        catalog_entries.append(("kycShutterDisc", "rupeeArt_kycShutterDisc", "wyglsst_kyc_pz"))

    # Keep original slice name for ID camera guide (no rotation).
    pzk_files: dict[str, Path] = {}
    for scale in ("2", "3"):
        pzk = SOURCE / f"wyglsst_pzk@{scale}x.png"
        if pzk.is_file():
            pzk_files[scale] = pzk
    if pzk_files:
        write_imageset("wyglsst_pzk", pzk_files)

    for stem, scales in pending.items():
        write_imageset(stem, scales)

    shutil.rmtree(tmp, ignore_errors=True)

    catalog_entries.sort(key=lambda item: item[1])
    catalog_path = Path("/Users/spirit/Desktop/FlexRupee/FlexRupee/Core/Theme/FlexSliceCatalog.swift")
    catalog_path.write_text(swift_catalog(catalog_entries), encoding="utf-8")

    print(f"Imported {copied} png files into {ASSETS}")
    print(f"Catalog constants: {len(catalog_entries)} -> {catalog_path}")


if __name__ == "__main__":
    main()

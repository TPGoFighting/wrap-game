#!/usr/bin/env python3
"""
package_android_apk.py - Inject optimized full WRAP.pck, loose assets, and clean boot parameters into Godot Android APK
"""
import sys
import os
import zipfile
import io

def package_apk(input_apk, pck_path, unpacked_dir, output_apk):
    if not os.path.exists(input_apk):
        print(f"Error: input APK not found: {input_apk}", file=sys.stderr)
        sys.exit(1)
        
    if not os.path.exists(pck_path):
        print(f"Error: PCK file not found: {pck_path}", file=sys.stderr)
        sys.exit(1)

    with open(pck_path, "rb") as f:
        pck_bytes = f.read()

    print(f"PCK size: {len(pck_bytes)} bytes ({len(pck_bytes) / (1024*1024):.2f} MB)")

    # Standard Android _cl_ command-line args for Godot
    # STRICT REQUIREMENT: DO NOT include --main-pack or --path!
    # Godot Android release templates are compiled with disable_path_overrides=yes,
    # so passing --main-pack will cause immediate engine abort/crash!
    args = [
        "--xr_mode_regular",
        "--xr-mode", "off",
        "--fullscreen",
        "--edge_to_edge",
        "--background_color", "#000000"
    ]
    cl_stream = io.BytesIO()
    cl_stream.write(len(args).to_bytes(4, "little"))
    for arg in args:
        b = arg.encode("utf-8")
        cl_stream.write(len(b).to_bytes(4, "little"))
        cl_stream.write(b)
    cl_bytes = cl_stream.getvalue()

    # Collect all loose files from unpacked_pck_opt to inject into assets/
    loose_files = {}
    if os.path.exists(unpacked_dir):
        for root, dirs, files in os.walk(unpacked_dir):
            for f in files:
                if f in ["export_presets.cfg", "project.godot"]:
                    continue
                full_p = os.path.join(root, f)
                rel_p = os.path.relpath(full_p, unpacked_dir).replace("\\", "/")
                with open(full_p, "rb") as in_f:
                    loose_files["assets/" + rel_p] = in_f.read()
        print(f"Collected {len(loose_files)} loose files from {unpacked_dir}")

    with zipfile.ZipFile(input_apk, "r") as zin, zipfile.ZipFile(output_apk, "w") as zout:
        written_entries = set()
        
        # 1. First copy non-assets and unmodified assets
        for item in zin.infolist():
            if item.filename.startswith("META-INF/"):
                continue # will be resigned
            if item.filename in ["assets/assets.sparsepck", "assets/_cl_", "assets/WRAP.pck"]:
                continue
            # If item is in loose_files, we will write our updated version
            if item.filename in loose_files:
                continue
            
            data = zin.read(item.filename)
            zout.writestr(item, data)
            written_entries.add(item.filename)

        # 2. Inject all loose assets (including .godot/exported, .godot/imported, main.tscn.remap, etc.)
        for path, data in loose_files.items():
            if path in written_entries:
                continue
            zinfo = zipfile.ZipInfo(path)
            # Store uncompressed for instant access
            zinfo.compress_type = zipfile.ZIP_STORED
            zout.writestr(zinfo, data)
            written_entries.add(path)

        # 3. Inject assets/assets.sparsepck (complete monolithic PCK)
        sparse_info = zipfile.ZipInfo("assets/assets.sparsepck")
        sparse_info.compress_type = zipfile.ZIP_STORED
        zout.writestr(sparse_info, pck_bytes)

        # 4. Inject clean _cl_ without --main-pack
        cl_info = zipfile.ZipInfo("assets/_cl_")
        cl_info.compress_type = zipfile.ZIP_STORED
        zout.writestr(cl_info, cl_bytes)

    out_size = os.path.getsize(output_apk)
    print(f"Repackaged unaligned APK successfully: {output_apk} ({out_size / (1024*1024):.2f} MB)")

if __name__ == "__main__":
    if len(sys.argv) < 5:
        print("Usage: package_android_apk.py <input_apk> <pck_path> <unpacked_dir> <output_apk>")
        sys.exit(1)
    package_apk(sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4])

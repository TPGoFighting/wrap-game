#!/usr/bin/env python3
"""
package_android_apk.py - Inject optimized full WRAP.pck and boot parameters into Godot Android APK
"""
import sys
import os
import zipfile
import io

def package_apk(input_apk, pck_path, output_apk):
    if not os.path.exists(input_apk):
        print(f"Error: input APK not found: {input_apk}", file=sys.stderr)
        sys.exit(1)
        
    if not os.path.exists(pck_path):
        print(f"Error: PCK file not found: {pck_path}", file=sys.stderr)
        sys.exit(1)

    with open(pck_path, "rb") as f:
        pck_bytes = f.read()

    print(f"PCK size: {len(pck_bytes)} bytes ({len(pck_bytes) / (1024*1024):.2f} MB)")

    # Construct Android _cl_ command-line args for Godot
    # Ensures engine knows to mount WRAP.pck as root pack
    args = [
        "--xr_mode_regular",
        "--xr-mode", "off",
        "--fullscreen",
        "--edge_to_edge",
        "--background_color", "#000000",
        "--main-pack", "WRAP.pck"
    ]
    cl_stream = io.BytesIO()
    cl_stream.write(len(args).to_bytes(4, "little"))
    for arg in args:
        b = arg.encode("utf-8")
        cl_stream.write(len(b).to_bytes(4, "little"))
        cl_stream.write(b)
    cl_bytes = cl_stream.getvalue()

    with zipfile.ZipFile(input_apk, "r") as zin, zipfile.ZipFile(output_apk, "w") as zout:
        for item in zin.infolist():
            # Strip old signature files so apksigner can produce clean V1+V2+V3 signature
            if item.filename.startswith("META-INF/"):
                continue
            # Will replace these two explicitly
            if item.filename in ["assets/assets.sparsepck", "assets/_cl_", "assets/WRAP.pck"]:
                continue
            
            data = zin.read(item.filename)
            zout.writestr(item, data)

        # Inject assets.sparsepck as uncompressed STORED
        sparse_info = zipfile.ZipInfo("assets/assets.sparsepck")
        sparse_info.compress_type = zipfile.ZIP_STORED
        zout.writestr(sparse_info, pck_bytes)

        # Inject assets/WRAP.pck as uncompressed STORED
        wrap_info = zipfile.ZipInfo("assets/WRAP.pck")
        wrap_info.compress_type = zipfile.ZIP_STORED
        zout.writestr(wrap_info, pck_bytes)

        # Inject assets/_cl_ as uncompressed STORED
        cl_info = zipfile.ZipInfo("assets/_cl_")
        cl_info.compress_type = zipfile.ZIP_STORED
        zout.writestr(cl_info, cl_bytes)

    out_size = os.path.getsize(output_apk)
    print(f"Repackaged unaligned APK successfully: {output_apk} ({out_size / (1024*1024):.2f} MB)")

if __name__ == "__main__":
    if len(sys.argv) < 4:
        print("Usage: package_android_apk.py <input_apk> <pck_path> <output_apk>")
        sys.exit(1)
    package_apk(sys.argv[1], sys.argv[2], sys.argv[3])

import zipfile, os, shutil

stage = r"C:\Users\mirco\brotato-mod-v2"
root = os.path.join(stage, "mods-unpacked")
out = os.path.join(stage, "YourName-CoopMaterialFix-1.3.0.zip")
workshop_dir = r"C:\Spiele\Steam\steamapps\workshop\content\1942280\3358859974"

if os.path.exists(out):
    os.remove(out)

with zipfile.ZipFile(out, "w", zipfile.ZIP_STORED) as z:
    z.writestr("mods-unpacked/", b"")
    z.writestr("mods-unpacked/YourName-CoopMaterialFix/", b"")
    z.writestr("mods-unpacked/YourName-CoopMaterialFix/extensions/", b"")
    z.writestr("mods-unpacked/YourName-CoopMaterialFix/extensions/singletons/", b"")
    z.writestr("mods-unpacked/YourName-CoopMaterialFix/extensions/items/", b"")
    z.writestr("mods-unpacked/YourName-CoopMaterialFix/extensions/items/global/", b"")
    for dirpath, dirnames, filenames in os.walk(root):
        for fn in filenames:
            full = os.path.join(dirpath, fn)
            rel = "mods-unpacked/" + os.path.relpath(full, root).replace("\\", "/")
            z.write(full, rel, compress_type=zipfile.ZIP_STORED)

with zipfile.ZipFile(out) as z:
    print("entries:", len(z.infolist()))

# Remove stale versions of this mod from the workshop folder so the loader
# never sees two zips with the same mod directory name.
for fn in os.listdir(workshop_dir):
    if fn.startswith("YourName-CoopMaterialFix-") and fn.endswith(".zip") and fn != os.path.basename(out):
        os.remove(os.path.join(workshop_dir, fn))
        print("removed stale:", fn)

shutil.copy(out, os.path.join(workshop_dir, os.path.basename(out)))
print("deployed v1.3.0")

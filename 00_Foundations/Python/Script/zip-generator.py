import pandas as pd
import os
import pyzipper
import tempfile
import shutil

INPUT_FILE = "users_not_in_system.xlsx"
OUTPUT_DIR = "output"

os.makedirs(OUTPUT_DIR, exist_ok=True)

df = pd.read_excel(INPUT_FILE)

for _, row in df.iterrows():

    login = str(row["Login"])
    password = str(row["Password"])
    zip_pass = str(row["Pass_to_extract"])

    print(f"Processing {login}")

    temp_dir = tempfile.mkdtemp()

    txt_path = os.path.join(temp_dir, "account.txt")

    with open(txt_path, "w", encoding="utf-8") as txt:
        txt.write(f"Login: {login}\n")
        txt.write(f"Password: {password}\n")

    zip_path = os.path.join(OUTPUT_DIR, f"{login}.zip")

    with pyzipper.AESZipFile(
        zip_path,
        "w",
        compression=pyzipper.ZIP_DEFLATED,
        encryption=pyzipper.WZ_AES
    ) as zf:
        zf.setpassword(zip_pass.encode())
        zf.write(txt_path, arcname="account.txt")

    shutil.rmtree(temp_dir)

print("All ZIP files created.")
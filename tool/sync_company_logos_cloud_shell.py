#!/usr/bin/env python3
"""Upload bundled company logos and link them to Firestore company records.

Run this script from an authenticated Google Cloud Shell with a
`company_logos/` directory beside it.
"""

from __future__ import annotations

import json
import mimetypes
import re
import subprocess
import sys
import urllib.parse
import urllib.request
import uuid
from datetime import datetime, timezone
from pathlib import Path


PROJECT_ID = "insurance-1178e"
BUCKET = "insurance-1178e.firebasestorage.app"
LOGO_DIR = Path(__file__).resolve().parent / "company_logos"

# Put more specific names first so life/health companies are not confused with
# similarly named general-insurance companies.
LOGO_MATCHES = (
    ("aditya birla sun life", "aditya-birla-sun-life.webp"),
    ("aditya birla health", "aditya-birla-health.png"),
    ("bajaj allianz life", "bajaj-allianz-life.png"),
    ("bajaj allianz general", "bajaj-allianz-general.png"),
    ("bajaj life insurance", "bajaj-allianz-life.png"),
    ("bajaj general insurance", "bajaj-allianz-general.png"),
    ("icici prudential", "icici-prudential-life.png"),
    ("icici lombard", "icici-lombard.png"),
    ("indusind nippon life", "indusind-nippon-life.png"),
    ("axis max life", "axis-max-life.png"),
    ("sbi general", "sbi-general.webp"),
    ("sbi life", "sbi-life.png"),
    ("iffco tokio", "iffco-tokio.png"),
    ("hdfc ergo", "hdfc-ergo.png"),
    ("united india", "united-india.png"),
    ("new india assurance", "new-india-assurance.png"),
    ("niva bupa", "niva-bupa.png"),
    ("care health", "care-health.png"),
    ("star health", "star-health.png"),
    ("galaxy health", "galaxy-health.png"),
    ("manipalcigna", "manipalcigna.png"),
    ("export credit guarantee corporation", "ecgc.jpg"),
    ("agriculture insurance company", "agriculture-insurance-company.png"),
)


def access_token() -> str:
    return subprocess.check_output(
        ["gcloud", "auth", "print-access-token"], text=True
    ).strip()


def normalize(value: str) -> str:
    return re.sub(r"[^a-z0-9]+", " ", value.lower()).strip()


def request_json(url: str, token: str, *, method: str = "GET", data=None):
    body = None if data is None else json.dumps(data).encode("utf-8")
    request = urllib.request.Request(
        url,
        data=body,
        method=method,
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
        },
    )
    with urllib.request.urlopen(request) as response:
        return json.load(response)


def firestore_companies(token: str) -> list[dict]:
    url = (
        "https://firestore.googleapis.com/v1/projects/"
        f"{PROJECT_ID}/databases/(default)/documents/insurance_companies?pageSize=1000"
    )
    return request_json(url, token).get("documents", [])


def string_field(document: dict, field: str) -> str:
    return document.get("fields", {}).get(field, {}).get("stringValue", "")


def matching_logo(company_name: str) -> str | None:
    normalized = normalize(company_name)
    for needle, filename in LOGO_MATCHES:
        if needle in normalized:
            return filename
    return None


def upload_logo(file_path: Path, document_id: str) -> tuple[str, str]:
    extension = file_path.suffix.lower() or ".png"
    object_path = f"company_logos/{document_id}/logo{extension}"
    download_token = str(uuid.uuid4())
    content_type = mimetypes.guess_type(file_path.name)[0] or "image/png"
    subprocess.run(
        [
            "gcloud",
            "storage",
            "cp",
            str(file_path),
            f"gs://{BUCKET}/{object_path}",
            f"--content-type={content_type}",
            "--cache-control=public,max-age=3600",
            f"--custom-metadata=firebaseStorageDownloadTokens={download_token}",
            "--quiet",
        ],
        check=True,
    )
    encoded_path = urllib.parse.quote(object_path, safe="")
    download_url = (
        f"https://firebasestorage.googleapis.com/v0/b/{BUCKET}/o/"
        f"{encoded_path}?alt=media&token={download_token}"
    )
    return object_path, download_url


def update_company(
    token: str,
    document_name: str,
    filename: str,
    storage_path: str,
    download_url: str,
) -> None:
    masks = urllib.parse.urlencode(
        [
            ("updateMask.fieldPaths", "logoUrl"),
            ("updateMask.fieldPaths", "logoStoragePath"),
            ("updateMask.fieldPaths", "logoFileName"),
            ("updateMask.fieldPaths", "logoSource"),
            ("updateMask.fieldPaths", "logoUpdatedAt"),
        ]
    )
    url = f"https://firestore.googleapis.com/v1/{document_name}?{masks}"
    now = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")
    request_json(
        url,
        token,
        method="PATCH",
        data={
            "fields": {
                "logoUrl": {"stringValue": download_url},
                "logoStoragePath": {"stringValue": storage_path},
                "logoFileName": {"stringValue": filename},
                "logoSource": {"stringValue": "bundled_asset_sync"},
                "logoUpdatedAt": {"timestampValue": now},
            }
        },
    )


def main() -> int:
    if not LOGO_DIR.is_dir():
        print(f"Missing logo directory: {LOGO_DIR}", file=sys.stderr)
        return 2

    token = access_token()
    companies = firestore_companies(token)
    updated: list[str] = []
    unmatched: list[str] = []

    for document in companies:
        company_name = string_field(document, "companyName")
        filename = matching_logo(company_name)
        if not filename:
            unmatched.append(company_name or document["name"])
            continue
        file_path = LOGO_DIR / filename
        if not file_path.is_file():
            raise FileNotFoundError(file_path)
        document_id = document["name"].rsplit("/", 1)[-1]
        storage_path, download_url = upload_logo(file_path, document_id)
        update_company(
            token,
            document["name"],
            filename,
            storage_path,
            download_url,
        )
        updated.append(company_name)
        print(f"Updated {company_name}: {storage_path}")

    expected_files = {filename for _, filename in LOGO_MATCHES}
    uploaded_files = {
        matching_logo(name) for name in updated if matching_logo(name) is not None
    }
    missing = sorted(expected_files - uploaded_files)
    print(
        json.dumps(
            {
                "project": PROJECT_ID,
                "companyDocuments": len(companies),
                "updated": len(updated),
                "unmatchedCompanies": unmatched,
                "missingExpectedLogos": missing,
            },
            indent=2,
        )
    )
    return 0 if not missing else 1


if __name__ == "__main__":
    raise SystemExit(main())

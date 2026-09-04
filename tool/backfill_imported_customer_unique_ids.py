import json
import re
from pathlib import Path
from urllib import error, parse, request


PROJECT_ID = "insurance-1178e"
BASE_URL = (
    f"https://firestore.googleapis.com/v1/projects/{PROJECT_ID}"
    "/databases/(default)/documents"
)
YEAR = 2026


def token():
    cfg_path = Path.home() / ".config" / "configstore" / "firebase-tools.json"
    cfg = json.loads(cfg_path.read_text())
    return cfg["tokens"]["access_token"]


def http(method, url, access_token, payload=None):
    data = None if payload is None else json.dumps(payload).encode()
    req = request.Request(
        url,
        data=data,
        method=method,
        headers={
            "Authorization": f"Bearer {access_token}",
            "Content-Type": "application/json",
        },
    )
    try:
        with request.urlopen(req, timeout=60) as resp:
            body = resp.read().decode()
            return resp.status, json.loads(body) if body else {}
    except error.HTTPError as exc:
        body = exc.read().decode()
        raise RuntimeError(f"{method} {url} failed {exc.code}: {body[:800]}")


def fs_value(value):
    if value is None:
        return {"nullValue": None}
    if isinstance(value, bool):
        return {"booleanValue": value}
    if isinstance(value, int):
        return {"integerValue": str(value)}
    if isinstance(value, float):
        return {"doubleValue": value}
    if isinstance(value, list):
        return {"arrayValue": {"values": [fs_value(v) for v in value]}}
    if isinstance(value, dict):
        return {"mapValue": {"fields": fs_fields(value)}}
    if isinstance(value, str) and re.fullmatch(r"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z", value):
        return {"timestampValue": value}
    return {"stringValue": str(value)}


def fs_fields(data):
    return {key: fs_value(value) for key, value in data.items()}


def decode_value(value):
    if not value:
        return None
    if "stringValue" in value:
        return value["stringValue"]
    if "integerValue" in value:
        return int(value["integerValue"])
    if "doubleValue" in value:
        return float(value["doubleValue"])
    if "booleanValue" in value:
        return bool(value["booleanValue"])
    if "timestampValue" in value:
        return value["timestampValue"]
    if "arrayValue" in value:
        return [decode_value(v) for v in value.get("arrayValue", {}).get("values", [])]
    if "mapValue" in value:
        return {
            key: decode_value(v)
            for key, v in value.get("mapValue", {}).get("fields", {}).items()
        }
    return None


def decode_doc(doc):
    return {
        "id": doc["name"].split("/")[-1],
        "path": doc["name"],
        "data": {
            key: decode_value(value)
            for key, value in doc.get("fields", {}).items()
        },
    }


def list_collection(collection, access_token):
    docs = []
    page_token = ""
    while True:
        url = f"{BASE_URL}/{collection}?pageSize=300"
        if page_token:
            url += f"&pageToken={parse.quote(page_token)}"
        _, body = http("GET", url, access_token)
        docs.extend(decode_doc(doc) for doc in body.get("documents", []))
        page_token = body.get("nextPageToken", "")
        if not page_token:
            return docs


def patch_doc(doc_path, fields, access_token):
    url = f"https://firestore.googleapis.com/v1/{doc_path}"
    masks = "".join(f"&updateMask.fieldPaths={parse.quote(k)}" for k in fields)
    sep = "?" if "?" not in url else "&"
    http("PATCH", f"{url}{sep}{masks.lstrip('&')}", access_token, {"fields": fs_fields(fields)})


def put_doc(collection, doc_id, fields, access_token):
    safe_id = parse.quote(doc_id, safe="")
    http("PATCH", f"{BASE_URL}/{collection}/{safe_id}", access_token, {"fields": fs_fields(fields)})


def delete_collection(collection, access_token):
    docs = list_collection(collection, access_token)
    for doc in docs:
        http("DELETE", f"https://firestore.googleapis.com/v1/{doc['path']}", access_token)
    return len(docs)


def category_code(category):
    key = (category or "").strip().lower()
    if key == "health":
        return "H"
    if key == "life":
        return "L"
    if key == "general":
        return "G"
    if key in {"agriculture", "agricultural"}:
        return "A"
    if key == "ecgc":
        return "E"
    return "G"


def sort_key(customer, policies_by_customer):
    data = customer["data"]
    dates = [
        policy["data"].get("policyStartDate") or policy["data"].get("issueDate") or ""
        for policy in policies_by_customer.get(customer["id"], [])
    ]
    return (
        min([date for date in dates if date] or ["9999"]),
        (data.get("name") or "").lower(),
        customer["id"],
    )


def lead_fields(category, sequence):
    code = category_code(category)
    lead_id = f"M{code}{YEAR}{sequence:05d}"
    return lead_id, {
        "leadUniqueId": lead_id,
        "uniqueLeadId": lead_id,
        "leadSerialNumber": lead_id,
        "leadSerialSequence": sequence,
        "leadSerialYear": YEAR,
        "leadSerialCategoryCode": code,
    }


def main():
    access_token = token()
    customers = list_collection("customers", access_token)
    policies = list_collection("customer_policies", access_token)
    revenue = list_collection("revenue", access_token)

    policies_by_customer = {}
    revenue_by_customer = {}
    for doc in policies:
        policies_by_customer.setdefault(doc["data"].get("customerId"), []).append(doc)
    for doc in revenue:
        revenue_by_customer.setdefault(doc["data"].get("customerId"), []).append(doc)

    customers = sorted(customers, key=lambda doc: sort_key(doc, policies_by_customer))
    deleted_registry = delete_collection("lead_serial_registry", access_token)

    updated_customers = 0
    updated_policies = 0
    updated_revenue = 0
    last_unique_id = ""

    for sequence, customer in enumerate(customers, 1):
        category = customer["data"].get("category") or "General"
        unique_id, fields = lead_fields(category, sequence)
        last_unique_id = unique_id
        search_key = f"{customer['data'].get('searchKey', '')} {unique_id}".strip().lower()
        patch_doc(customer["path"], {**fields, "searchKey": search_key}, access_token)
        updated_customers += 1

        for policy in policies_by_customer.get(customer["id"], []):
            patch_doc(policy["path"], fields, access_token)
            updated_policies += 1
        for row in revenue_by_customer.get(customer["id"], []):
            patch_doc(row["path"], fields, access_token)
            updated_revenue += 1

        put_doc(
            "lead_serial_registry",
            unique_id,
            {
                "leadUniqueId": unique_id,
                "sequence": sequence,
                "year": YEAR,
                "category": category,
                "categoryCode": fields["leadSerialCategoryCode"],
                "leadId": customer["id"],
                "leadName": customer["data"].get("name") or "Unnamed",
                "status": "Allocated",
            },
            access_token,
        )

    put_doc(
        "system_counters",
        f"lead_serial_{YEAR}",
        {
            "year": YEAR,
            "lastSequence": len(customers),
            "lastLeadUniqueId": last_unique_id,
        },
        access_token,
    )

    print(
        json.dumps(
            {
                "deletedOldRegistry": deleted_registry,
                "updatedCustomers": updated_customers,
                "updatedCustomerPolicies": updated_policies,
                "updatedRevenue": updated_revenue,
                "registryCount": len(customers),
                "counter": {
                    "year": YEAR,
                    "lastSequence": len(customers),
                    "lastLeadUniqueId": last_unique_id,
                },
            },
            indent=2,
        )
    )


if __name__ == "__main__":
    main()

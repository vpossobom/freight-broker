import os
import json
import urllib.parse
import requests

def lambda_handler(event, context):
    """
    AWS Lambda handler to check carrier eligibility using FMCSA QCMobile API.
    Expects an HTTP GET request with query param: ?mc=<carrier_name_or_number>
    """

    fmcsa_key = os.environ["FMCSA_API_KEY"]

    params = event.get("queryStringParameters") or {}
    carrier_query = params.get("mc")

    if not carrier_query:
        return {
            "statusCode": 400,
            "body": json.dumps({"error": "Missing required parameter 'mc'"})
        }

    url = f"https://mobile.fmcsa.dot.gov/qc/services/carriers/docket-number/{carrier_query}?webKey={fmcsa_key}"

    try:
        response = requests.get(url, timeout=10)
        response.raise_for_status()
        data = response.json()

        content = data.get("content")
        carrier_info = content[0] if content else None

        if not carrier_info:
            return {"statusCode": 404, "body": json.dumps({"error": "Carrier not found"})}

        eligible = carrier_info.get("allowedToOperate", "N") == "Y"

        result = {
            "mcNumber": carrier_info.get("mcNumber"),
            "dotNumber": carrier_info.get("dotNumber"),
            "legalName": carrier_info.get("legalName"),
            "dbaName": carrier_info.get("dbaName"),
            "telephone": carrier_info.get("telephone"),
            "eligible": eligible
        }

        return {
            "statusCode": 200,
            "headers": { "Content-Type": "application/json" },
            "body": json.dumps(result)
        }

    except Exception as e:
        return {
            "statusCode": 500,
            "body": json.dumps({"error": str(e)})
        }

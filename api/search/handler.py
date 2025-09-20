import os
import json
from pymongo import MongoClient
from datetime import datetime

client = None

def lambda_handler(event, context):
    global client
    mongo_uri = os.environ["MONGO_URI"]
    db_name = os.environ.get("DB_NAME", "freight")

    if client is None:
        client = MongoClient(mongo_uri)
    db = client[db_name]

    # Params from API Gateway
    params = event.get("queryStringParameters") or {}
    equipment = params.get("equipment_type")
    weight = params.get("weight")
    origin = params.get("origin")
    destination = params.get("destination")
    commodity = params.get("commodity_type")
    pickup_after = params.get("pickup_after")      # ISO8601
    delivery_before = params.get("delivery_before")# ISO8601
    deadline_datetime = params.get("deadline_datetime")  # legacy param
    print(params)
    # Parse numeric parameters with validation
    skip = 0
    if params.get("skip"):
        try:
            skip = int(params.get("skip"))
        except (ValueError, TypeError):
            skip = 0
    
    limit = 3
    if params.get("limit"):
        try:
            limit = int(params.get("limit"))
        except (ValueError, TypeError):
            limit = 3

    # Build base query
    query = {}
    if equipment:
        query["equipment_type"] = equipment.lower()
    if weight:
        query["weight"] = {"$lte": int(weight)}
    if origin:
        query["origin"] = origin.lower()
    if destination:
        query["destination"] = destination.lower()
    if commodity:
        query["commodity_type"] = commodity.lower()

    if pickup_after:
        pickup_after_clean = pickup_after.strip('"\'')
        query["pickup_datetime"] = {"$gte": pickup_after_clean}

    if delivery_before:
        delivery_before_clean = delivery_before.strip('"\'')
        query["delivery_datetime"] = {"$lte": delivery_before_clean}

    if deadline_datetime:
        deadline_clean = deadline_datetime.strip('"\'')
        query["delivery_datetime"] = {"$lte": deadline_clean}


    # Fetch from Mongo with skip + limit
    loads = list(db.loads.find(query).skip(skip).limit(limit * 5))  
    # fetch more than limit so we can sort before slicing

    feasible = []
    for load in loads:
        try:
            # Compute rate per mile
            if load.get("miles") and load.get("loadboard_rate"):
                load["rate_per_mile"] = round(
                    load["loadboard_rate"] / load["miles"], 2
                )

            load["_id"] = str(load["_id"])
            feasible.append(load)

        except Exception:
            continue

    # Sort by rate per mile (highest first) and apply pagination
    ranked = sorted(feasible, key=lambda x: x.get("rate_per_mile", 0), reverse=True)
    topn = ranked[skip:skip + limit]

    print(topn)

    return {
        "statusCode": 200,
        "headers": { "Content-Type": "application/json" },
        "body": json.dumps(topn)
    }

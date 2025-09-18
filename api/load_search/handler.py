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
    skip = int(params.get("skip", 0))
    limit = int(params.get("limit", 3))            # default: 3

    # Build base query
    query = {}
    if equipment:
        query["equipment_type"] = equipment
    if weight:
        query["weight"] = {"$lte": int(weight)}
    if origin:
        query["origin"] = origin
    if destination:
        query["destination"] = destination
    if commodity:
        query["commodity_type"] = commodity
    if pickup_after:
        query["pickup_datetime"] = {"$gte": datetime.fromisoformat(pickup_after)}
    if delivery_before:
        query["delivery_datetime"] = {"$lte": datetime.fromisoformat(delivery_before)}
    if deadline_datetime:  # fallback to deadline filter
        query["delivery_datetime"] = {"$lte": datetime.fromisoformat(deadline_datetime)}

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

    return {
        "statusCode": 200,
        "body": json.dumps(topn)
    }

# Freight Broker API

This document explains how to access the Freight Broker API and how to reproduce the deployment if needed. The deployment is fully automated via Docker and Terraform.

## Quick Start

Clone the repository and build the Docker image:

```bash
git clone <repo-url>
cd freight-broker
docker build -t freight-broker .
```

Configure environment variables in `infra/terraform.tfvars`:

```hcl
fmcsa_api_key = "your-fmcsa-api-key-here"
mongo_uri     = "mongodb://your-mongo-connection-string"
```

Run the deployment:

```bash
docker run --rm -it \
  -e AWS_ACCESS_KEY_ID=<your-access-key> \
  -e AWS_SECRET_ACCESS_KEY=<your-secret-key> \
  -e AWS_DEFAULT_REGION=us-east-1 \
  -v $(pwd):/app \
  freight-broker
```

Retrieve your API endpoint and key:

```bash
cd infra
terraform output api_endpoint
terraform output -raw api_key
```

Test the API:

```bash
curl -i \
  -H "x-api-key: <your-api-key>" \
  "https://<api-id>.execute-api.us-east-1.amazonaws.com/prod/eligibility?mc=12345"
```

---

## Accessing the API

The API is deployed on AWS API Gateway with REST API and native API key authentication.

**Base URL:**

```
https://<api-id>.execute-api.us-east-1.amazonaws.com/prod
```

### Getting Your API Key

After deployment, retrieve your API key:

```bash
cd infra
terraform output -raw api_key
```

### Endpoints

1. **Eligibility Check**

   Example request:

   ```bash
   curl -i \
     -H "x-api-key: <your-api-key>" \
     "https://<api-id>.execute-api.us-east-1.amazonaws.com/prod/eligibility?mc=12345"

   ```

2. **Search Feasible Loads**

   Example request:

   ```bash
   curl -i \
     -H "x-api-key: <your-api-key>" \
     "https://<api-id>.execute-api.us-east-1.amazonaws.com/prod/search_feasible_loads?equipment_type=van&origin=ATL&destination=DAL&limit=5"

   ```

Both endpoints require the API key via the `x-api-key` header.

### Rate Limiting

The API includes built-in rate limiting:

- **Rate Limit**: 50 requests per second
- **Burst Limit**: 100 requests

### Logs

Logs are available in AWS CloudWatch under:

- `/aws/lambda/carrier_eligibility`
- `/aws/lambda/search_feasible_loads`

---

## Database Setup

This project uses MongoDB to store carrier and load data.

### Creating your MongoDB instance

1. Create a MongoDB Atlas cluster (or run MongoDB locally).
2. Create a database named `freight` (default, or update `DB_NAME` env var).
3. Create a collection named `loads` with documents in the format:

```json
{
  "origin": "Dallas, TX",
  "destination": "Atlanta, GA",
  "pickup_datetime": "2025-09-22T09:00:00",
  "delivery_datetime": "2025-09-25T18:00:00",
  "equipment_type": "Reefer",
  "commodity_type": "Frozen chicken",
  "weight": 40000,
  "miles": 800,
  "loadboard_rate": 2200
}
```

---

## Reproducing the Deployment

The recommended way to reproduce or redeploy this system is through the provided Docker build environment. This approach ensures consistency across different machines.

### Prerequisites

- Docker installed on your machine
- AWS credentials with permissions for Lambda, API Gateway, and IAM
- Required API keys and connection strings

### Step 1: Configure Environment Variables

Create a `terraform.tfvars` file in the `infra/` directory with your configuration:

```hcl
# infra/terraform.tfvars
fmcsa_api_key = "your-fmcsa-api-key-here"
mongo_uri     = "mongodb://your-mongo-connection-string"
db_name       = "freight"  # optional, defaults to "freight"
```

**Required Variables:**

- `fmcsa_api_key`: Your FMCSA API key for carrier eligibility checks
- `mongo_uri`: MongoDB connection string for load data

**Optional Variables:**

- `db_name`: Database name (defaults to "freight")
- `aws_region`: AWS region (defaults to "us-east-1")

### Step 2: Build the Deployment Container

From the project root, run:

```bash
docker build -t freight-broker .
```

### Step 3: Run the Deployment

Run the container with your AWS credentials:

```bash
docker run --rm -it \
  -e AWS_ACCESS_KEY_ID=<your-access-key> \
  -e AWS_SECRET_ACCESS_KEY=<your-secret-key> \
  -e AWS_DEFAULT_REGION=us-east-1 \
  -v $(pwd)/infra:/workspace/infra \
  freight-broker
```

This will:

- Package the Lambda functions into `.zip` files
- Run Terraform (`init` + `apply`) to provision AWS resources
- Keep the container alive for log streaming and troubleshooting

### Step 4: Verify the Deployment

Once complete, get your API endpoint and key:

```bash
cd infra
terraform output api_endpoint
terraform output -raw api_key
```

You can verify by running the sample `curl` commands from the **Accessing the API** section.

## Components Deployed

- **Two AWS Lambda functions:**

  - `carrier_eligibility` - Checks carrier eligibility via FMCSA API
  - `search_feasible_loads` - Searches available loads from MongoDB

- **API Gateway REST API:**

  - Native API key authentication
  - Rate limiting and throttling
  - HTTPS enabled by default

- **Usage Plan:**

  - API key enforcement
  - Rate limiting (50 req/sec, burst 100)
  - Throttling protection

- **CloudWatch Logging:**
  - Automatic logging for all Lambda functions
  - API Gateway access logs

---

## Security Features

- **API Key Authentication**: All endpoints require valid API keys
- **Rate Limiting**: Built-in protection against abuse
- **HTTPS Only**: All traffic encrypted in transit
- **AWS IAM**: Proper role-based permissions
- **Environment Variables**: Sensitive data stored securely

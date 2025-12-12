# Frontend Deployment Quick Start

## Deploy to Cloud Storage + CDN

### One-Command Deployment
```bash
cd /home/code/myagents/MyAgentsFrontend-staging

gcloud builds submit \
  --config=cloudbuild-deploy.yaml \
  --project=myagents-475112 \
  --region=us-central1
```

### Expected Output
- Build time: ~10-15 minutes
- Steps: 10 (build → upload → CDN → CORS → validation)
- Result: Static site at https://storage.googleapis.com/myagents-frontend/

### Access Your Frontend
**Storage URL (CDN-backed):**
```
https://storage.googleapis.com/myagents-frontend/index.html
```

**Backend Bucket:**
```
myagents-frontend-backend (Cloud CDN enabled)
```

### Verify Deployment
```bash
# Check bucket contents
gsutil ls -r gs://myagents-frontend/

# Check CORS configuration
gsutil cors get gs://myagents-frontend/

# Check backend bucket
gcloud compute backend-buckets describe myagents-frontend-backend \
  --project=myagents-475112

# Test frontend access
curl -I https://storage.googleapis.com/myagents-frontend/index.html
```

### Troubleshooting

**Build fails at Flutter build step:**
```bash
# Check Docker image exists
gcloud container images list --project=myagents-475112 | grep myagentsfrontend-test

# Rebuild test image first
gcloud builds submit --config=cloudbuild.yaml --project=myagents-475112
```

**CORS errors in browser:**
```bash
# Verify CORS configuration
gsutil cors get gs://myagents-frontend/

# Test with curl
curl -v -H "Origin: https://myagents-frontend.web.app" \
  https://storage.googleapis.com/myagents-frontend/index.html
```

**CDN not enabled:**
```bash
# Check backend bucket CDN status
gcloud compute backend-buckets describe myagents-frontend-backend \
  --project=myagents-475112 \
  --format="value(enableCdn)"
```

### Configuration Details

**Project:** myagents-475112
**Region:** us-central1
**Bucket:** gs://myagents-frontend/
**Relay:** wss://relay.remoteagents.dev/ws/client/{pairingCode}

**Cache Headers:**
- HTML: 1 hour
- JS/CSS: 1 year (immutable)
- Assets: 1 year (immutable)
- Icons: 1 day

**CORS Origins:**
- https://myagents-frontend.web.app
- https://*.web.app
- https://*.run.app
- http://localhost:*

### Next Steps

1. Test frontend in browser
2. Verify WebSocket connection to relay
3. Test pairing flow with CLI
4. Monitor CDN cache hit rate
5. (Optional) Set up custom domain

### Documentation

- Full report: DEPLOYMENT_REPORT.md
- Cloud Build config: cloudbuild-deploy.yaml
- CI/CD docs: CI_CD.md

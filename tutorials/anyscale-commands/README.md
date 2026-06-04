# Anyscale Command Reference

Practical commands for working with jobs, services, and the cluster. Everything you need after submitting a workload.

---

## Jobs

### Submit
```bash
anyscale job submit --cloud eks-ray-cloud \
  --working-dir <dir> \
  --config-file <dir>/job.yaml

# Or with a submit script
./tutorials/<name>/submit.sh
```

### List all jobs
```bash
anyscale job list
```

### Status of latest job by name
```bash
anyscale job status --name <job-name>
```

### Status by job ID
```bash
anyscale job status --id <prodjob_xxx>
```

### Stream logs (latest by name)
```bash
anyscale job logs --name <job-name>
```

### Stream logs by ID
```bash
anyscale job logs --id <prodjob_xxx>
```

### Follow logs in real time
```bash
anyscale job logs --name <job-name> --follow
```

### Terminate a running job
```bash
anyscale job terminate --name <job-name>
anyscale job terminate --id <prodjob_xxx>
```

---

## Services

### Deploy
```bash
anyscale service deploy -f ./service.yaml

# Or with a deploy script
./tutorials/<name>/deploy.sh
```

### List all services
```bash
anyscale service list
```

### Status
```bash
anyscale service status --name <service-name>
```

### Logs and rollout history
```bash
# Service logs are in the Anyscale console:
# console.anyscale.com/services → click service → Logs tab

# Or via kubectl (get pod name first):
kubectl get pods -n anyscale-operator
kubectl logs <pod-name> -n anyscale-operator
```

### Query a running service
```bash
# Get token + URL from deploy output, then:
curl -H "Authorization: Bearer <TOKEN>" <BASE_URL>/hello?name=World

# Or via Python
python3 tutorials/service-hello-world/query.py --token <TOKEN> --url <BASE_URL>
```

### Terminate a service
```bash
anyscale service terminate --name <service-name>
```

> Always terminate services before running `./anyscale/teardown.sh`

---

## Cloud

### List registered clouds
```bash
anyscale cloud list
```

### Inspect cloud registration (zones, operator role, S3 bucket)
```bash
anyscale cloud get --name eks-ray-cloud
```

### Re-run functional verification
```bash
anyscale cloud verify --name eks-ray-cloud
```

---

## Kubernetes — Node & Pod Inspection

### Check all nodes
```bash
kubectl get nodes -o wide
```

### Check Karpenter NodeClaims (what nodes Karpenter provisioned)
```bash
kubectl get nodeclaims
kubectl get nodeclaims -o wide
```

### Check all pods in the Anyscale namespace
```bash
kubectl get pods -n anyscale-operator
```

### Describe a specific pod (events, resource requests, node affinity)
```bash
kubectl describe pod <pod-name> -n anyscale-operator
```

### Check GPU node capacity
```bash
kubectl describe node <node-name> | grep -A 10 "Capacity:\|Allocatable:\|nvidia"
```

### Check NVIDIA device plugin
```bash
kubectl get pods -n kube-system | grep nvidia
```

---

## Kubernetes — Karpenter Logs

### Live Karpenter logs (provisioning decisions, errors)
```bash
kubectl logs -n karpenter -l app.kubernetes.io/name=karpenter -f
```

### Last 60 seconds of Karpenter logs
```bash
kubectl logs -n karpenter -l app.kubernetes.io/name=karpenter --since=60s
```

### Filter for scheduling errors
```bash
kubectl logs -n karpenter -l app.kubernetes.io/name=karpenter --since=120s \
  | grep -i "error\|provision\|nodeclaim"
```

---

## Kubernetes — NodePools

### Check NodePool status
```bash
kubectl get nodepools
```

### Apply / update NodePool
```bash
kubectl apply -f cluster/gpu-nodepool.yaml
```

### Check ingress (for Ray head node DNS)
```bash
kubectl get ingress -A
```

---

## Common Debugging Sequence

Job is stuck or failing:

```bash
# 1. Check job state
anyscale job status --name <job-name>

# 2. Read logs
anyscale job logs --name <job-name>

# 3. Check if a node was provisioned
kubectl get nodeclaims

# 4. Check pod state
kubectl get pods -n anyscale-operator

# 5. Describe the stuck pod
kubectl describe pod <pod-name> -n anyscale-operator

# 6. Check Karpenter for scheduling errors
kubectl logs -n karpenter -l app.kubernetes.io/name=karpenter --since=120s \
  | grep -i error
```

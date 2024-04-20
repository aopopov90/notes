<!-- @import "[TOC]" {cmd="toc" depthFrom=1 depthTo=6 orderedList=false} -->

# Cluster Set-up

Certificate locations:
- CA, api-server, kubelet, etcd: /etc/kubernetes/pki
- controller-manager (in file): /etc/kubernetes/controller-manager.conf
- scheduler: /etc/kubernetes/scheduler.conf
- kubelet-client: /etc/kubernetes/kubelet.conf
- kubelet-server: /var/lib/kubelet/pki


## Connecting to kube-apiserver via NodePort (not recommended)

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: read-all-resources
rules:
- apiGroups: [""]
  resources: ["*"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["authorization.k8s.io"]
  resources: ["selfsubjectaccessreviews"]
  verbs: ["create"]
- apiGroups: [""]
  resources: ["pods/portforward"]
  verbs: ["create"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: anonymous-read-access
subjects:
- kind: User
  name: system:anonymous
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: read-all-resources
  apiGroup: rbac.authorization.k8s.io
```
Change the `kubernetes` svc in the default namespace to NodePort type. Note a new port. Get external IP from the master console.
Should be able to curl after that form external:
```

```bash
curl -k https://34.147.199.27:30732/api/v1/namespaces/default/pods
```

Configuring kubectl:
```bash
kubectl config set-cluster cks --server=https://34.147.199.27:30732 --insecure-skip-tls-verify=true
kubectl config set-credentials system:anonymous --token=""
kubectl config set-context cks --cluster=cks --user=system:anonymous
kubectl config use-context cks
```

## Calling secure ingress with the --resolve option
```bash
curl https://secure-ingress.com:30846/service2 -vk --resolve secure-ingress.com:30846:34.147.138.133
```

## Interacting with the metadata service

https://cloud.google.com/compute/docs/metadata/overview

```bash
# the following works both from node directly and from a pod
curl -vk http://metadata.google.internal/computeMetadata/v1/project/ -H "Metadata-Flavor: Google"
curl -vk http://metadata.google.internal/computeMetadata/v1/instance/disks/ -H "Metadata-Flavor: Google"
```

### Protect with network policies:

```yaml
# all pods in namespace cannot access metadata endpoint
# https://github.com/killer-sh/cks-course-environment/blob/master/course-content/cluster-setup/protect-node-metadata/np_cloud_metadata_deny.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: cloud-metadata-deny
  namespace: default
spec:
  podSelector: {}
  policyTypes:
  - Egress
  egress:
  - to:
    - ipBlock:
        cidr: 0.0.0.0/0
        except:
        - 169.254.169.254/32
```

Allow for only specific pods:
```yaml
# https://github.com/killer-sh/cks-course-environment/blob/master/course-content/cluster-setup/protect-node-metadata/np_cloud_metadata_allow.yaml
# only pods with label are allowed to access metadata endpoint
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: cloud-metadata-allow
  namespace: default
spec:
  podSelector:
    matchLabels:
      role: metadata-accessor
  policyTypes:
  - Egress
  egress:
  - to:
    - ipBlock:
        cidr: 169.254.169.254/32
```

## Running kube-bench

https://github.com/aquasecurity/kube-bench
https://raw.githubusercontent.com/aquasecurity/kube-bench/main/job.yaml

or 

```bash
# see all
kube-bench run --targets master

# or just see the one
kube-bench run --targets master --check 1.2.20
```

## Watch container status
```bash
watch crictl ps
```

## Verify kube-apiserver binary running inside container

Check current version of k8s server with: `kubectl get nodes`.
Then download it: `curl -LO https://dl.k8s.io/v1.28.2/kubernetes-server-linux-amd64.tar.gz`.
Unzip it: `tar -xvf kubernetes-server-linux-amd64.tar.gz`.
Capture hash of a binary from the tarball: `sha512sum kubernetes/server/bin/kube-apiserver > compare`.
Now we need to get hash of a running binary. Getting it via `kubectl exec` may not be possible because these binaries are usually distroless, so no shell.
Instead do the following. (Optional) Check that the container is running: `crictl ps | grep kube-apiserver`.
Identify the process pid (e.g. 1519): `ps aux | grep kube-apiserver`.
Find the binary within the process directory: `find /proc/1519/root | grep kube-api`.
Capture checksum and compare with the one captured form the downloaded binary: `sha512sum /proc/1519/root/usr/local/bin/kube-apiserver >> compare`.


# Cluster Hardening

## RBAC

```bash
# namespace-scoped
k -n blue create role secret-manager --verb=get --verb=list --resource=secrets
k -n blue create rolebinding secret-manager --role=secret-manager --user=jane
k auth can-i list secrets --as jane -n blue

# cluster-scoped
k create clusterrole deploy-deleter --verb delete --resource deployments
k create clusterrolebinding deploy-deleter --clusterrole=deploy-deleter --user=jane
k -n red create rolebinding deploy-deleter --user jim --clusterrole deploy-deleter
k auth can-i delete deployments --as jane -A # yes
k auth can-i delete deployments --as jane -n red # yes
k auth can-i delete deployments --as jim -n red # yes 
k auth can-i delete deployments --as jim -n blue # no
```
Example with SAs:
```bash
k create clusterrolebinding pipeline --clusterrole view --serviceaccount ns1:pipeline --serviceaccount ns2:pipeline
k auth can-i delete deployments --as=system:serviceaccount:ns1:pipeline -n ns1
```

## Requesting certificate
Create cert
```bash
# https://kubernetes.io/docs/reference/access-authn-authz/certificate-signing-requests/#create-private-key

# create csr
openssl genrsa -out jane.key 2048
openssl req -new -key jane.key -out jane.csr -subj "/CN=jane"
cat jane.csr | base64 -w 0

# manually signing (this is an alternative method)
openssl x509 -req -in /root/60099.csr -CAkey /etc/kubernetes/pki/ca.key -CA /etc/kubernetes/pki/ca.crt -CAcreateserial -out /root/60099.crt -days 500

# deploy csr
cat <<EOF | kubectl apply -f -
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: jane
spec:
  request: <CSR_here>
  signerName: kubernetes.io/kube-apiserver-client
  expirationSeconds: 86400  # one day
  usages:
  - client auth
EOF

# approve the CSR
k certificate approve jane

# extract cert from the CSR
k get csr jane -oyaml
# or
k get csr 60099@internal.users -ojsonpath="{.status.certificate}"
```

Configure kubectl
```bash
# add a user
k config set-credentials jane --client-key=./jane.key --client-certificate=./jane.crt
# or with the `--embed-certs` flag for the certs to be included in the config directly rather than being referenced
k config set-credentials jane --client-key=./jane.key --client-certificate=./jane.crt --embed-certs
# view config (`--raw` flag to see certs)
k config view --raw
# create a context
k config set-context jane --user=jane --cluster=kubernetes
# verify a context
k config get-contexts
# switch to the new user (i.e. context)
k config use-context jane
```

## Service accounts

Authenticate as an SA:
```bash
# create sa
k create sa accessor
# create token (new token each time) - jwt token
k create token accessor
# run a pod (with the accessor sa under .spec.serviceAccountName)
k run nginx --image nginx
# connect to the pod and find the SA location
k exec nginx -- mount | grep ser
# call k8s api as the sa
curl https://${KUBERNETES_PORT_443_TCP_ADDR} -k -H "Authorization: Bearer $(cat token)"
```

## Disable the auto-mount of the SA

[Opt out of api credential automounting](https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/#opt-out-of-api-credential-automounting)

Add the `automountServiceAccountToken: false` param to the SA.
Or, use the same property in the pod spec.
```bash
# forcefully recreate the pod
k -f pod.yaml replace --force
```

## Enable/disable anonymous access for kube-apiserver

> [!NOTE]
> Log locations to check in case kube-apiserver doesn't come back:
> /var/log/pods
> /var/log/containers
> crictl ps + crictl logs
> docker ps + docker logs (in case when Docker is used)
> kubelet logs: /var/log/syslog or journalctl

```bash
# 403 if anonymous enabled; 401 if disabled
curl https://localhost:6443 -k
```

To disable add `- --anonymous-auth=false` param to the kube-apiserver spec: `/etc/kubernetes/manifests/kube-apiserver.yaml`.

## Enable/disable insecure port

To enable: `--insecure_port=8080`.
To disable: `--insecure_port=0`

## Authenticating to kube-apiserver directly

```bash
# display config with keys
k config --raw
# save 'client-certificate-data' to ca.crt
# save 'client-key-data' to tls.key
# save 'client-certificate-data' to tls.crt
echo "<key>" | base64 -d > ca.crt
# call the api with curl (host is also in the config)
curl https://10.154.0.2:6443 --cert ./tls.crt --key ./tls.key --cacert ./ca.crt
```

## Expose kube-apiserver externally

1. Change svc type for `kubernetes` to `NodePort`. Note the port in the svc and the node external IP of the master (in gcp console).
2. Run `k config view --raw` on the master and copy the contents. Save the contents on a local system.
3. The config needs to be updated with the external IP & port of the kube-apiserver. 
   However, running it against the IP directly will produce the following error:
   `Unable to connect to the server: x509: certificate is valid for 10.96.0.1, 10.154.0.2, not 34.142.60.255`.
   This is because the kube-apiserver certificate is issued for only two IPs and a few hosts.
   This can be verified by inspecting the `X509v3 Subject Alternative Name` attribute of the server cert
   with the `openssl x509 -in /etc/kubernetes/pki/apiserver.crt --text` command.
   Example:
   `DNS:cks-master, DNS:kubernetes, DNS:kubernetes.default, DNS:kubernetes.default.svc, DNS:kubernetes.default.svc.cluster.local, IP Address:10.96.0.1, IP Address:10.154.0.2`
   Note one of the DNS names, e.g. `kubernetes`.
4. Add a new entry to the `/etc/hosts` file locally, e.g.:
   `34.142.60.255 kubernetes`
5. Update the kube config: `server: https://kubernetes:30732`. Should work now.

## Node restriction 

1. Check that kube-apiserver has the following param `--enable-admission-plugins=NodeRestriction`
2. ssh into the worker node
3. Set kubelet config as a default config for kubectl: `export KUBECONFIG=/etc/kubernetes/kubelet.conf`
4. Should be able to list nodes now: `k get nodes`
5. Try labelling the master node (NO): `k label node cks-master cks/test=yes`
   Try labelling itself (i.e. the worker node) (YES): `k label node cks-worker cks/test=yes`
   Try labelling itself with a restricted label (NO): `k label node cks-worker node-restriction.kubernetes.io/test=yes`
   response: `Error from server (Forbidden): nodes "cks-worker" is forbidden: is not allowed to modify labels: node-restriction.kubernetes.io/test`

This gives administrator the assurance that nodes can not run some secure pods on themselves.

## Upgrade control plane one version up

Follow this guide: https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-upgrade/

# Minimise Microservice vulnerabilities

## Inspecting secrets by calling k8s api from a containe

Attach to a container and check sa token is present (if `automountServiceAccountToken` enabled):
```bash
➜ k -n restricted exec -it pod3-748b48594-24s76 -- sh

/ # mount | grep serviceaccount
tmpfs on /run/secrets/kubernetes.io/serviceaccount type tmpfs (ro,relatime)

/ # ls /run/secrets/kubernetes.io/serviceaccount
ca.crt     namespace  token
```

Get the secrets by calling the API:
```bash
/ # curl https://kubernetes.default/api/v1/namespaces/restricted/secrets -H "Authorization: Bearer $(cat /run/secrets/kubernetes.io/serviceaccount/token)" -k
...
    {
      "metadata": {
        "name": "secret3",
        "namespace": "restricted",
...
          }
        ]
      },
      "data": {
        "password": "cEVuRXRSYVRpT24tdEVzVGVSCg=="
      },
      "type": "Opaque"
    }
...
```

## Inspecting secrets with container runtime

This example shows how easily accessible secrets are if you have root access to node.
It is not considered a big security issue, because node root access should be restricted.
```bash
# identify container id (e.g e12da85338362)
crictl ps
# identify container pid (e.g. 2920)
crictl inspect e12da85338362 | grep pid
# locate the secret (has to be a correct volume mount path)
cat /proc/2920/root/etc/secret-volume/password
```

## Inspecting secrets with etcd (cli)

This demonstrates that secrets in ETCD as stored unencrypted by default.
```bash
# first check how kube-api-server connects to etcd
cat /etc/kubernetes/manifests/kube-apiserver.yaml | grep etcd

# the result will be similar to below
    # - --etcd-cafile=/etc/kubernetes/pki/etcd/ca.crt
    # - --etcd-certfile=/etc/kubernetes/pki/apiserver-etcd-client.crt
    # - --etcd-keyfile=/etc/kubernetes/pki/apiserver-etcd-client.key
    # - --etcd-servers=https://127.0.0.1:2379

# now check health
ETCDCTL_API=3 etcdctl \
  --cert /etc/kubernetes/pki/apiserver-etcd-client.crt \
  --key /etc/kubernetes/pki/apiserver-etcd-client.key \
  --cacert /etc/kubernetes/pki/etcd/ca.crt \
  endpoint health

# check 'creds' secret in the 'default' namespace
ETCDCTL_API=3 etcdctl \
  --cert /etc/kubernetes/pki/apiserver-etcd-client.crt \
  --key /etc/kubernetes/pki/apiserver-etcd-client.key \
  --cacert /etc/kubernetes/pki/etcd/ca.crt \
  get /registry/secrets/default/creds
```

## Encrypting secrets in ETCD (at rest)

Encrypt all existing secrets using **aescbc** and a password of our choice.

```bash
# create a new folder
cd /etc/kubernetes/
mkdir etcd && cd etcd
# grab starting configuration from here and modify:
# https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/#write-an-encryption-configuration-file
# generate a password with 16 chars manually; `echo -n passwordpassword | base64`
cat <<EOF > ec.yaml
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
  - resources:
      - secrets
    providers:
      - aescbc:
          keys:
            - name: key1
              # See the following text for more details about the secret value
              secret: cGFzc3dvcmRwYXNzd29yZA==
      - identity: {}
EOF
```

Now inject this configuration into the kube-apiserver pod at `/etc/kubernetes/manifests/kube-apiserver.yaml`.

Add a volume:
```yaml
volumes:
  - hostPath:
      path: /etc/kubernetes/etcd
      type: DirectoryOrCreate
    name: etcd
```

Add a volume mount:
```yaml
    volumeMounts:
    - mountPath: /etc/kubernetes/etcd
      name: etcd
      readOnly: true
```

Add an argument:
```yaml
--encryption-provider-config=/etc/kubernetes/etcd/ec.yaml
```

The existing secrets will still be accessible from ETCD in a plain form (just repeat previous example).
However, newly created secrets will be encrypted.
To encrypt all existing secrets just recreate them.
If you make a config change to a provider object (such as comment out the identity field) in the `EncryptionConfiguration`, 
kube-apiserver will no longer be able to read existing secrets.

To recreate all secrets run:
```bash
kubectl get secrets --all-namespaces -o json | kubectl replace -f -
```
The output should be encrypted and prefixed with k8s:enc:aesgcm:v1:key1.
After this, can delete the identity provider from the config.

Note: in production it's best not to store an encr key directly on the master node. It's better to use an external KMS plugin.

## Interacting with Kernel from a container

Below demonstrates that the same Kernel version is shown when executed both from a container and a master
```bash
# create a pod and connect
k run pod --image=nginx
k exec pod -it -- bash

# get Kernel version
uname -r

# execute the same on a master node directly (will be the same)
exit
uname -r

# see kernel calls
strace uname -r
```

## Create and use RuntimeClasses for runtime runsc (gVisor)

```bash
# search 'runtime class' on k8s docs
# adapt an example by setting 'handler' to 'runsc'
cat <<EOF > rc.yaml
apiVersion: node.k8s.io/v1
kind: RuntimeClass
metadata:
  name: gvisor
handler: runsc 
EOF

k create -f rc.yaml

# then create a pod and specify '.spec.runtimeClassName=gvisor'
# the pod will be stuck
# Warning  FailedCreatePodSandBox  2s (x2 over 15s)  kubelet            Failed to create pod sandbox: rpc error: code = Unknown desc = failed to get sandbox runtime: no runtime for "runsc" is configured
```

Now need to install runsc on nodes (optional for the CKS exam)
```bash
# install gvisor on a node
bash <(curl -s https://raw.githubusercontent.com/killer-sh/cks-course-environment/master/course-content/microservice-vulnerabilities/container-runtimes/gvisor/install_gvisor.sh)

# check containerd and kubelet statuses
service containerd status
service kubelet status

# pod should be running now
# connect to the pod and check kernel version (should be different from the node kernel, e.g `4.4.0`)
k exec -it gvisor -- uname -r

# verify gvisor is running
k exec -it gvisor -- dmesg
```

## Security Context

Check default.
```bash
# run a pod with a command 
k run pod --image busybox --command -o yaml --dry-run=client > pod.yaml -- sh -c 'sleep 1d'

# run 'id'
# should see:
# id=0(root) gid=0(root) groups=10(wheel)
k exec -it pod -- id
# create a file and check perms (will be owned by root)
```

Now inject security context:
```yaml
spec:
  securityContext:
    runAsUser: 1000
    runAsGroup: 3000
```
Test
```bash
# run 'id'
# should see 'uid=1000 gid=3000'
# should not be able to create a file (except /tmp/)
```

Now indicate that containers must run as non-run:
```yaml
  containers:
  - securityContext:
      runAsNonRoot: true
```
If you delete pod level security context (i.e. sets a non-root user) it will try to run as root and will fail.

## Privileged containers

Enable privileged and test using sysctl.
```bash
# run the pod as root
# try executing sysctl
k exec -it pod -- sysctl kernel.hostname=attacker
# this will fail:
# sysctl: error setting key 'kernel.hostname': Read-only file system
```
Now make it privileged:
```yaml
spec:
  containers:
  - securityContext:
      privileged: true
```
Should be able to access Kernel:
```bash
k exec pod -- sysctl kernel.hostname=attacker
```

## Disable Privilege Escalation

k8s has this enabled by default.
So first verify it (with `allowPrivilegeEscalation: true` or with no changes):
```bash
cat /proc/1/status | grep NoNewPrivs
# should see - 0
```
Now set `allowPrivilegeEscalation: false` and repeat the test. Should see "NoNewPrivs:     1"

## Create a proxy sidecar with NET_ADMIN capability

Create a simple pod that pings Google:
```bash
k run app --image=bash --command -oyaml --dry-run=client > app.yaml -- sh -c 'ping google.com'
```

Add a sidecar container with iptables and capabilities defined:
```yaml
  - name: proxy
    image: ubuntu
    securityContext:
      capabilities:
        add: ["NET_ADMIN"]
    command:
    - sh
    - -c
    - 'apt-get update && apt-get install iptables -y && iptables -L && sleep 1d'
```

Deploy the pod and check sidecar log. Should see the following:
```
Setting up iptables (1.8.7-1ubuntu5.1) ...
update-alternatives: using /usr/sbin/iptables-legacy to provide /usr/sbin/iptables (iptables) in auto mode
update-alternatives: using /usr/sbin/ip6tables-legacy to provide /usr/sbin/ip6tables (ip6tables) in auto mode
update-alternatives: using /usr/sbin/iptables-nft to provide /usr/sbin/iptables (iptables) in auto mode
update-alternatives: using /usr/sbin/ip6tables-nft to provide /usr/sbin/ip6tables (ip6tables) in auto mode
update-alternatives: using /usr/sbin/arptables-nft to provide /usr/sbin/arptables (arptables) in auto mode
update-alternatives: using /usr/sbin/ebtables-nft to provide /usr/sbin/ebtables (ebtables) in auto mode
Processing triggers for libc-bin (2.35-0ubuntu3.6) ...
Chain INPUT (policy ACCEPT)
target     prot opt source               destination         

Chain FORWARD (policy ACCEPT)
target     prot opt source               destination         

Chain OUTPUT (policy ACCEPT)
target     prot opt source               destination 
```

## Open Policy Agent (OPA)

Check that kube-apiserver.yaml only has `--enable-admission-plugins=NodeRestriction`. Remove others if there are any.
Install the gatekeeper: `kubectl create -f https://raw.githubusercontent.com/killer-sh/cks-course-environment/master/course-content/opa/gatekeeper.yaml`

### Deny All

Create constraint template: https://github.com/killer-sh/cks-course-environment/blob/master/course-content/opa/deny-all/alwaysdeny_template.yaml
Check that the constraint template created:
```bash
k get constrainttemplate.templates.gatekeeper.sh
# should see `k8salwaysdeny` template
```

Create 'pod-always-deny' constraint: https://github.com/killer-sh/cks-course-environment/blob/56946116ed10fc6fcc4c9cc6887b475ecd82cf63/course-content/opa/deny-all/all_pod_always_deny.yaml#L4

Check constraint created:
```bash
k get k8salwaysdeny
# should see pod-always-deny
```

Try scheduling a pod. Should see" `Error from server ([pod-always-deny] ACCESS DENIED!): admission webhook "validation.gatekeeper.sh" denied the request: [pod-always-deny] ACCESS DENIED!`

Inspect the constraint log: `k describe k8salwaysdeny pod-always-deny`

### Allow All

Change `1 > 0` to `1 > 2` in the `k8salwaysdeny` template.

### All namespaces created need to have the label 'cks'

Template: https://github.com/killer-sh/cks-course-environment/blob/56946116ed10fc6fcc4c9cc6887b475ecd82cf63/course-content/opa/namespace-labels/k8srequiredlabels_template.yaml
Constraint: https://github.com/killer-sh/cks-course-environment/blob/56946116ed10fc6fcc4c9cc6887b475ecd82cf63/course-content/opa/namespace-labels/all_ns_must_have_cks.yaml

```bash
k describe k8srequiredlabels ns-must-have-cks
```

# Supply Chain Security

## Reduce image size using a multi-stage build

A single stage build would produce an image that is about ~700 MB (huge).
The multi-stage image will be ~10 MB max (in this example).

Example:
```docker
# stage 0
FROM ubuntu
ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y golang-go
COPY app.go .
RUN CGO_ENABLED=0 go build app.go

# stage 1
FROM alpine
COPY --from=0 /app .

CMD ["./app"]
```

## Secure and harden images

### Use specific tags
Use specific tags:
- `FROM ubuntu:20.04`
- `FROM alpine:3.19.1`

Pin versions in the package managers (e.g. apt-get) as well, will be more reliable.

### Don't run as root
Don't run as root. Example
```docker
# abridged

# app container stage 2
FROM alpine:3.12.0
RUN addgroup -S appgroup && adduser -S appuser -G appgroup -h /home/appuser
COPY --from=0 /app /home/appuser/
USER appuser
CMD ["/home/appuser/app"]
```

### Make filesystem read-only

```docker
# abridged

# app container stage 2
FROM alpine:3.12.0
RUN chmod a-w /etc
```

Rebuild and run detached: `docker run -d app`.

```bash
docker exec -it <container_id> sh
# note /etc doesn't have write permissions
ls -lh / | grep etc
```

### Remove shell access

In dockerfile, remove the entire `/bin` directory at the end: `RUN rm -rf /bin/*`
Example:
```docker
# abridged

# app container stage 2
FROM alpine:3.12.0
RUN chmod a-w /etc
RUN addgroup -S appgroup && adduser -S appuser -G appgroup -h /home/appuser
RUN rm -rf /bin/*
COPY --from=0 /app /home/appuser/
USER appuser
CMD ["/home/appuser/app"]
```

Read best practices: https://docs.docker.com/develop/develop-images/instructions/

Won't be able to run shell interactively now:
`OCI runtime exec failed: exec failed: unable to start container process: exec: "sh": executable file not found in $PATH: unknown`

## Static Analysis

### Kubesec

Kubesec can be used to scan YAML templates.
```bash
# generate a pod spec
k run nginx --image nginx -oyaml --dry-run=client > pod.yaml

# scan
docker run -i kubesec/kubesec:512c5e0 scan /dev/stdin < pod.yaml
```

### Conftest - OPA

Can be used to verify k8s resources.
```
# from https://www.conftest.dev
package main

deny[msg] {
  input.kind = "Deployment"
  not input.spec.template.spec.securityContext.runAsNonRoot = true
  msg = "Containers must not run as root"
}

deny[msg] {
  input.kind = "Deployment"
  not input.spec.selector.matchLabels.app
  msg = "Containers must provide app label for pod selectors"
}
```

Run analysis.
```bash
docker run --rm -v $(pwd):/project openpolicyagent/conftest test deploy.yaml
```

Can also be used to verify Docker files.
```
package commands

denylist = [
  "apk",
  "apt",
  "pip",
  "curl",
  "wget",
]

deny[msg] {
  input[i].Cmd == "run"
  val := input[i].Value
  contains(val[_], denylist[_])

  msg = sprintf("unallowed commands found %s", [val])
}
```
Execute:
```bash
docker run --rm -v $(pwd):/project openpolicyagent/conftest test Dockerfile --all-namespaces 
```

## Image vulnerability scanning with Trivy

Trivy downloads vuln database and scans an image.
```bash
docker run aquasec/trivy image trinodb/trino:438
```

## Use Image Digest

Use all images used in the whole cluster:
```bash
k get pod -A -oyaml | grep "image:" | grep -v "f:"
```
Look at yaml of the kube-apiserver. Grab the value of `imageID` field (includes digest). Update the manifest to use the image with a digest. Should work.
`registry.k8s.io/kube-apiserver@sha256:98a686df810b9f1de8e3b2ae869e79c51a36e7434d33c53f011852618aec0a68`

## Whitelist some registries using OPA

Only images from docker.io and k8s.gcr.io can be used.

Create template and constraint from here: https://github.com/killer-sh/cks-course-environment/tree/master/course-content/supply-chain-security/secure-the-supply-chain/whitelist-registries/opa

```yaml
apiVersion: templates.gatekeeper.sh/v1beta1
kind: ConstraintTemplate
metadata:
  name: k8strustedimages
spec:
  crd:
    spec:
      names:
        kind: K8sTrustedImages
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package k8strustedimages

        violation[{"msg": msg}] {
          image := input.review.object.spec.containers[_].image
          not startswith(image, "docker.io/")
          not startswith(image, "k8s.gcr.io/")
          msg := "not trusted image!"
        }
---
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sTrustedImages
metadata:
  name: pod-trusted-images
spec:
  match:
    kinds:
      - apiGroups: [""]
        kinds: ["Pod"]
```

This won't work anymore: `k run nginx --image=nginx`
This will: `k run nginx --image=docker.io/nginx`

## Investigate ImagePolicyWebhook

Have it call an external service.

Add the following flag to the kube-apiserver.yaml: `--enable-admission-plugins=NodeRestriction,ImagePolicyWebhook`.
API won't work anymore. Check log (in /var/log/pods):
```
2024-02-16T07:25:30.441985957Z stderr F E0216 07:25:30.441762       1 run.go:74] "command failed" err="failed to apply admission: couldn't init admission plugin \"ImagePolicyWebhook\": no config specified"
```

Copy example:
```
git clone https://github.com/killer-sh/cks-course-environment.git
cp -r cks-course-environment/course-content/supply-chain-security/secure-the-supply-chain/whitelist-registries/ImagePolicyWebhook/ /etc/kubernetes/admission
```

Check /etc/kubernetes/admission/admission_config.yaml
```yaml
apiVersion: apiserver.config.k8s.io/v1
kind: AdmissionConfiguration
plugins:
  - name: ImagePolicyWebhook
    configuration:
      imagePolicy:
        kubeConfigFile: /etc/kubernetes/admission/kubeconf
        allowTTL: 50
        denyTTL: 50
        retryBackoff: 500
        # pods will be denied even if the webhook server is not reachable
        defaultAllow: false
```

Check /etc/kubernetes/admission/kubeconf
```yaml
apiVersion: v1
kind: Config

# clusters refers to the remote service.
clusters:
- cluster:
    certificate-authority: /etc/kubernetes/admission/external-cert.pem  # CA for verifying the remote service.
    server: https://external-service:1234/check-image                   # URL of remote service to query. Must use 'https'.
  name: image-checker

contexts:
- context:
    cluster: image-checker
    user: api-server
  name: image-checker
current-context: image-checker
preferences: {}

# users refers to the API server's webhook configuration.
users:
- name: api-server
  user:
    client-certificate: /etc/kubernetes/admission/apiserver-client-cert.pem     # cert for the webhook admission controller to use
    client-key:  /etc/kubernetes/admission/apiserver-client-key.pem             # key matching the cert
```

Add `--admission-control-config-file=/etc/kubernetes/admission/admission_config.yaml` flag to kube-apiserver.yaml.
Mount the dir:
```yaml
volumeMounts:
  - mountPath: /etc/kubernetes/admission
    name: k8s-admission
    readOnly: true
```
```yaml
volumes:
- hostPath:
    path: /etc/kubernetes/admission
    type: DirectoryOrCreate
  name: k8s-admission
```

Try creating a pod:
```bash
root@cks-master:/etc/kubernetes/admission# k ruin test --image=nginx
Error from server (Forbidden): pods "test" is forbidden: Post "https://external-service:1234/check-image?timeout=30s": dial tcp: lookup external-service on 169.254.169.254:53: no such host
```

This is because the external admission service hasn't been configured. Set `defaultAllow: true` in admission_config.yaml.
Reboot the kube-apiserver:
```bash
mv /etc/kubernetes/manifests/kube-apiserver.yaml /tmp/
mv /tmp/kube-apiserver.yaml /etc/kubernetes/manifests/kube-apiserver.yaml
```

The pod creation will now be possible.

# Monitoring, Logging and Runtime Security

## strace: show syscalls

```bash
strace ls /
# summary view
strace -cw ls /
```

## strace and /proc: etcd

```bash
# get etcd process
ps aux | grep etcd
# inspect the process
strace -p 1453
# summary
strace -p 1453 -f -cw
```

## Create Apache pod with a secret as an environment variable

Read the secret from the host system.
Create a pod with an env variable. Note the process id.
Do `cat /proc/4465/environ`. The env var value should be there. 

Note: secrets as environment variables can be seen by anyone who can access /proc on the host. 

## Install Falco on a worker node

 Install from here: https://github.com/killer-sh/cks-course-environment/blob/master/Resources.md#runtime-security---behavioral-analytics-at-host-and-container-level

 `service falco start`
 Check log: `tail /var/log/syslog | grep falco`

 ## Use Falco to find malicious processes inside containers

Stream Falco logs on the worker node: `tail -f /var/log/syslog | grep falco`.
Should also be able to view logs via: `journalctl -fu falco`.
On a master node connect to the pod `k exec -it apache -- sh`.
Should see some Falco log (on a worker node):
```
 Feb 17 17:00:52 cks-worker falco: 17:00:52.468329957: Notice A shell was spawned in a container with an attached terminal (user=root user_loginuid=-1 apache (id=1dcf91c0aad1) shell=sh parent=<NA> cmdline=sh terminal=34816 container_id=1dcf91c0aad1 image=docker.io/library/httpd) 
```

Edit `/etc/passwd`: `echo user >> /etc/passwd`.
Falco sees it:
```
Feb 17 17:07:03 cks-worker falco: 17:07:03.981272893: Error File below /etc opened for writing (user=root user_loginuid=-1 command=sh parent=<NA> pcmdline=<NA> file=/etc/passwd program=sh gparent=<NA> ggparent=<NA> gggparent=<NA> container_id=1dcf91c0aad1 image=docker.io/library/httpd)
```

Add a liveness probe that updates packages:
```yaml
    livenessProbe:
      exec:
        command:
        - apt-get
        - update
      initialDelaySeconds: 5
      periodSeconds: 5
```
Falco will be reporting it:
```
Feb 17 17:12:21 cks-worker falco: 17:12:21.552159595: Error Package management process launched in container (user=root user_loginuid=-1 command=apt-get update container_id=94393180619a container_name=apache image=docker.io/library/httpd:latest)
```

The difference between Liveness probe and a readiness probe:
- if a container fails readiness checks it keeps running, however, the whole pod is marked as non-ready, thus not receiving traffic
- if a container fails liveness checks that specific container gets restarted

## Look at some Falco rules

```bash
cd /etc/falco
# explore the following files 
vim falco_rules.yaml 
vim k8s_audit_rules.yaml 
```

## Change a Falco rule

Copy the whole rule from `/etc/falco/falco_rules.yaml`:
```yaml
- rule: Terminal shell in container
  desc: A shell was used as the entrypoint/exec point into a container with an attached terminal.
  condition: >
    spawned_process and container
    and shell_procs and proc.tty != 0
    and container_entrypoint
    and not user_expected_terminal_shell_in_container_conditions
  output: >
    A shell was spawned in a container with an attached terminal (user=%user.name user_loginuid=%user.loginuid %container.info
    shell=%proc.name parent=%proc.pname cmdline=%proc.cmdline terminal=%proc.tty container_id=%container.id image=%container.image.repository)
  priority: NOTICE
  tags: [container, shell, mitre_execution]
```

Put a rule in `/etc/falco/falco_rules.local.yaml` and modify.
Fields here: https://falco.org/docs/reference/rules/supported-fields/
For the updates to take effect, Falco needs to be hot-reloaded: `kill -1 $(cat /var/run/falco.pid)`

## Remove executables from a container using startupProbes

```yaml
containers:
- startupProbe:
  exec:
    command:
    - rm
    - /bin/bash
```

## Create Pod SecurityContext to make filesystem read-only

Ensure some directories are still writable using emptyDir volume.

Set security context:
```yaml
  containers:
  - securityContext:
      readOnlyRootFilesystem: true
```
The the app will be crashing, check log:
```
[Sun Feb 18 09:12:28.335369 2024] [core:error] [pid 1:tid 140217599285120] (30)Read-only file system: AH00099: could not create /usr/local/apache2/logs/httpd.pid.JuHy0l
[Sun Feb 18 09:12:28.335489 2024] [core:error] [pid 1:tid 140217599285120] AH00100: httpd: could not log pid to file /usr/local/apache2/logs/httpd.pid
```
Configure an emptyDir volume:
```yaml
  containers:
  - volumeMounts:
    - mountPath:  /usr/local/apache2/logs
      name: cache-volume
  volumes:
  - name: cache-volume
    emptyDir:
      sizeLimit: 500Mi
```
Should work after a restart.
The container is read-only now:
```bash
k exec immutable -- touch test
touch: cannot touch 'test': Read-only file system
command terminated with exit code 1 
```

Similar can be done in docker:
```bash
docker run --read-only --tmpfs /run my-container 
```

## Configure apiserver to store Audit Logs in JSON format

 ```bash
# create a simple policy file
mkdir -p /etc/kubernetes/audit
cd /etc/kubernetes/audit
cat <<EOF > policy.yaml
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
- level: Metadata
EOF
```
Configure kube-apiserver (/etc/kubernetes/manifests/kube-apiserver.yaml):
 ```yaml
...
spec:
  containers:
  - command:
    - kube-apiserver
    - --audit-policy-file=/etc/kubernetes/audit/policy.yaml
    - --audit-log-path=/etc/kubernetes/audit/log/audit.log
    - --audit-log-maxsize=500
    - --audit-log-maxbackup=5
...
    volumeMounts:
    - mountPath: /etc/kubernetes/audit
      name: audit
...
  volumes:
  - hostPath:
      path: /etc/kubernetes/audit
      type: DirectoryOrCreate
    name: audit
 ```

 Docs: https://kubernetes.io/docs/tasks/debug/debug-cluster/audit/#log-backend
 Example: https://github.com/killer-sh/cks-course-environment/blob/master/course-content/runtime-security/auditing/kube-apiserver_enable_auditing.yaml

 ## Create a secret and investigate the JSON audit log

Create a secret:
```bash
k create secret generic very-secure --from-literal=user=admin
```

Inspectl log entry (`cat ./log/audit.log | grep very-secure`):
```json
{
    "kind": "Event",
    "apiVersion": "audit.k8s.io/v1",
    "level": "Metadata",
    "auditID": "98a1cb54-ed79-4705-99ff-f25900358dd8",
    "stage": "ResponseComplete",
    "requestURI": "/api/v1/namespaces/default/secrets?fieldManager=kubectl-create\u0026fieldValidation=Strict",
    "verb": "create",
    "user": {
        "username": "kubernetes-admin",
        "groups": [
            "system:masters",
            "system:authenticated"
        ]
    },
    "sourceIPs": [
        "10.154.0.2"
    ],
    "userAgent": "kubectl/v1.28.6 (linux/amd64) kubernetes/be3af46",
    "objectRef": {
        "resource": "secrets",
        "namespace": "default",
        "name": "very-secure",
        "apiVersion": "v1"
    },
    "responseStatus": {
        "metadata": {},
        "code": 201
    },
    "requestReceivedTimestamp": "2024-02-19T07:34:39.986194Z",
    "stageTimestamp": "2024-02-19T07:34:39.991989Z",
    "annotations": {
        "authorization.k8s.io/decision": "allow",
        "authorization.k8s.io/reason": "",
        "failed-open.validating.webhook.admission.k8s.io/round_0_index_0": "validation.gatekeeper.sh"
    }
}
```

## Restrict logged data with an Audit Policy

- Nothing from stage RequestReceived
- Nothing from 'Get', 'Watch', 'List'
- From Secrets only metadata level
- Everything else RequestResponse level

```yaml
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
- level: RequestResponse
- level: None
  verbs: ["watch", "get", "list" ]
- level: Metadata
  resources:
  - group: ""
    resources: ["secrets"]
omitStages:
  - "RequestReceived"
```

# System Hardening

## SetUp simple AppArmour profile for curl

 ```bash
# check status
aa-status

# install additional tools
apt-get install apparmor-utils

# generate a new profile for curl (press F)
aa-genprof curl

# try running curl; will get 'could not resolve host'
curl -v killer.sh

# check status again - should see 26 instead of 25 profiles 

# the profiles are located in `/etc/apparmour.d`
# check 'curl' profile
vim /etc/apparmor.d/usr.bin.curl
# to update a profile, first run
# this will list the attempted operations
# can choose 'A' to allow; the profile will be updated accordingly
aa-logprof

# check the profile again, should see new entries such as '  #include <abstractions/openssl>'
# curl command shoudl work
 ```

## Nginx Docker container that is using AppArmor profile

Download this script as `/etc/apparmor.d/docker-nginx`: https://github.com/killer-sh/cks-course-environment/blob/master/course-content/system-hardening/kernel-hardening-tools/apparmor/profile-docker-nginx

Use `apparmor_parser` command to install.
Example: https://kubernetes.io/docs/tutorials/security/apparmor/#example
```bash
# install profile
apparmor_parser /etc/apparmor.d/docker-nginx
# check status
aa-status
```
Run docker wiht an apparmor profile:
```bash
docker run --security-opt apparmor=docker-nginx -d nginx
docker exec -it <container_id> sh
# try creating files; should not work
touch /root/test
``` 

## Using AppArmor in k8s

Docs with an example: https://kubernetes.io/docs/tutorials/security/apparmor/#pod-annotation

Create a pod with an annotation pointing to a non-existent container:
```yaml
apiVersion: v1
kind: Pod
metadata:
  creationTimestamp: null
  labels:
    run: secure
  annotations:
    container.apparmor.security.beta.kubernetes.io/secure: localhost/hello 
  name: secure
spec:
  containers:
  - image: nginx
    name: secure
    resources: {}
  dnsPolicy: ClusterFirst
  restartPolicy: Always
status: {}
```

Start the pod, it won't pass readiness checks. Error:
```
Warning  Failed     12s (x5 over 41s)  kubelet            Error: failed to get container spec opts: failed to generate apparmor spec opts: apparmor profile not found hello
```

Create it with an existing profile (on a pod level):
```yaml
annotations:
    container.apparmor.security.beta.kubernetes.io/secure: localhost/docker-nginx
```

Verify (on a node where container is running):
```bash
crictl inspect <container_id> | grep apparmor
```

## Running nginx Docker container with seccomp

Save into default.json the following file: https://github.com/killer-sh/cks-course-environment/blob/master/course-content/system-hardening/kernel-hardening-tools/seccomp/profile-docker-nginx.json

```bash
# run with seccomp profile
docker run --security-opt seccomp=default.json nginx
```

## Create a Nginx Pod in k8s and assign a seccomp profile to it

Doc: https://kubernetes.io/docs/tutorials/security/seccomp/#create-a-pod-with-a-seccomp-profile-for-syscall-auditing
Add the following security context to a pod:
```yaml
  securityContext:
    seccompProfile:
      type: Localhost
      localhostProfile: profiles/audit.json
```

Try creating a pod. Should see the following error:
```
 Warning  Failed     11s (x2 over 13s)  kubelet            Error: failed to create containerd container: cannot load seccomp profile "/var/lib/kubelet/seccomp/profiles/audit.json": open /var/lib/kubelet/seccomp/profiles/audit.json: no such file or directory
```

Copy the `default.json` to `/var/lib/kubelet/seccomp/profiles/default.json`. Update the pod security context too.
Recreate the pod, it should be running now.

## Disable Snapd service via systemctl 

Common `systemctl` commands.
```bash
# check service status
systemctl status snapd

# stop service
systemctl stop snapd

# list services
systemctl list-units

# check for a specific service
systemctl list-units | grep snapd

# or filter
systemctl list-units --type=service --state=running | grep snapd

# you can stop a service; but it will be started again on system reboot
systemctl stop snapd

# disable to prevent it from being started
systemctl disable snapd 
```

## Install and investigate services

```bash
# install services
apt-get update && apt-get install vsftpd samba

# start the service and check status
systemctl start smbd
systemctl status smbd

# check processes
ps aux | grep vsftpd
ps aux | grep smbd

# check ports
netstat -plnt | grep smbd 
```

## Find and disable the app listening on port 21

```bash
# check for a process (will be vsftpd)
netstat -plnt | grep 21
lsof -i :21

# identity service name (will be vsftpd.service)
systemctl list-units --type=service | grep ftp

# disable service
systemctl disable vsftpd.service

# run netstat or lsof again; should not have anything
```

## Investigate linux users

```bash
# list users
cat /etc/passwd

# login as a specific user
su ubuntu && whoami

# become 'root' again
sudo -i

# check logged in users
ps aux | grep bash 

# create a user (provide password interactively)
adduser test

# as a root you can log in as any user without password  
```

# Misc

## Linux user and group management

- To find out UID of a user either use `id <username>` command or `cat /etc/passw`
- To change password, as root, run: `passwd <username>` and when prompted, enter the password
- To delete user and groups use `userdel` and `groupdel` commands
- To suspend a user, run: `usermod -s /usr/sbin/nologin <username>`. This will make sure that the user can no longer login with their credentials
- Create a user named sam on the controlplane host. The user's home directory must be /opt/sam. Login shell must be /bin/bash and uid must be 2328. Make sam a member of the admin group.
  Solution: `useradd -d /opt/sam -s /bin/bash -G admin -u 2328 sam`

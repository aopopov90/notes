<!-- @import "[TOC]" {cmd="toc" depthFrom=1 depthTo=6 orderedList=false} -->

Certificate locations:
- CA, api-server, kubelet, etcd: /etc/kubernetes/pki
- controller-manager (in file): /etc/kubernetes/controller-manager.conf
- scheduler: /etc/kubernetes/scheduler.conf
- kubelet-client: /etc/kubernetes/kubelet.conf
- kubelet-server: /var/lib/kubelet/pki


# Connecting to kube-apiserver via NodePort (not recommended)

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

```
curl -k https://34.147.199.27:30732/api/v1/namespaces/default/pods
```

Configuring kubectl:
```
kubectl config set-cluster cks --server=https://34.147.199.27:30732 --insecure-skip-tls-verify=true
kubectl config set-credentials system:anonymous --token=""
kubectl config set-context cks --cluster=cks --user=system:anonymous
kubectl config use-context cks
```

# Cluster Setup
## Calling secure ingress with the --resolve option
```
curl https://secure-ingress.com:30846/service2 -vk --resolve secure-ingress.com:30846:34.147.138.133
```

## Interacting with the metadata service

https://cloud.google.com/compute/docs/metadata/overview

```
# the following works both from node directly and from a pod
curl -vk http://metadata.google.internal/computeMetadata/v1/project/ -H "Metadata-Flavor: Google"
curl -vk http://metadata.google.internal/computeMetadata/v1/instance/disks/ -H "Metadata-Flavor: Google"
```

Protect with network policies:
```
# https://github.com/killer-sh/cks-course-environment/blob/master/course-content/cluster-setup/protect-node-metadata/np_cloud_metadata_deny.yaml
# all pods in namespace cannot access metadata endpoint
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
```
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
```
https://raw.githubusercontent.com/aquasecurity/kube-bench/main/job.yaml
```

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

Disable the auto-mount of the SA

# https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/#opt-out-of-api-credential-automounting
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

## Encrypting secrets in ETCD

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

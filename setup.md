```bash
gcloud auth login
gcloud config set project protean-atom-410915
gcloud config set compute/zone europe-west2-c
```

Create master vm
```
gcloud compute instances create cks-master --project=protean-atom-410915 --zone=europe-west2-c --machine-type=e2-medium --network-interface=network-tier=PREMIUM,stack-type=IPV4_ONLY,subnet=default --maintenance-policy=MIGRATE --provisioning-model=STANDARD --service-account=53721505590-compute@developer.gserviceaccount.com --scopes=https://www.googleapis.com/auth/devstorage.read_only,https://www.googleapis.com/auth/logging.write,https://www.googleapis.com/auth/monitoring.write,https://www.googleapis.com/auth/servicecontrol,https://www.googleapis.com/auth/service.management.readonly,https://www.googleapis.com/auth/trace.append --create-disk=auto-delete=yes,boot=yes,device-name=cks-master,image=projects/ubuntu-os-cloud/global/images/ubuntu-2004-focal-v20240110,mode=rw,size=50,type=projects/protean-atom-410915/zones/europe-west2-c/diskTypes/pd-balanced --no-shielded-secure-boot --shielded-vtpm --shielded-integrity-monitoring --labels=goog-ec-src=vm_add-gcloud --reservation-affinity=any
```

Create worker vm
```

```


```bash
# ssh into master
gcloud compute ssh cks-master

# install 
sudo -i
bash <(curl -s https://raw.githubusercontent.com/killer-sh/cks-course-environment/master/cluster-setup/latest/install_master.sh)

# ssh into worker
gcloud compute ssh cks-worker

# install 
sudo -i
bash <(curl -s https://raw.githubusercontent.com/killer-sh/cks-course-environment/master/cluster-setup/latest/install_worker.sh)

# add a worker node (copy command from master log and execute on the worker node)
kubeadm join 10.154.0.2:6443 --token ukusnr.xlqas2x0zk42ofy6 --discovery-token-ca-cert-hash sha256:8e8eea0441f4be5885f35596fdd18b909cc05ba41f6430abfe187f616ef91ef0 

# on a local terminal run the following to create a firewall-rule 
# to make cluster accessible from outside (specificallyports 30100 and 30244)
gcloud compute firewall-rules create nodeports --allow tcp:30000-40000
```
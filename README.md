# Kubernetes Private Registry with Azure

This repo contains a fully functionnal solution to deploy a **Private Docker Registry** within your **Kubernetes Cluster** using an **Azure Blob Storage** as backend.

# Creation of the Azure Storage account

To use the Azure Blob Storage as a Docker Registry, the first step is to create a Storage Account on your Azure Subscription.

> **Note:** **Premium Storage Accounts** are not supported by Docker Registry. (Registry uses block blobs, but only page blobs are supported on Premium Storage.)

You need to create that Storage Account in a separate "Ressource Group" than your Kubernetes cluster, to ensure the safety of your images.

# Quick Deployment

You can deploy the registry quickly by doing the following, setting variables to your values as appropriate. **Please read the script before running.** It removes existing kube-registry resources before deploying!

```shell
$ export AZURE_RESOURCE_GROUP=colemick-persist-strg
$ export AZURE_STORAGE_ACCOUNT=colemickpersiststrgstd
$ export AZURE_STORAGE_CONTAINER=registry
$ make deploy
./do.sh deploy
secret "azure-storage-key" created
deployment "kube-registry" created
service "kube-registry" created
daemonset "kube-registry-proxy" created
```

You can destroy the kube-registry-azure deployment by doing:
```shell
$ make destroy
./do.sh destroy
secret "azure-storage-key" deleted
deployment "kube-registry" deleted
service "kube-registry" deleted
daemonset "kube-registry-proxy" deleted
```

If you change the environment variables you can run this. It will redeploy
the secret and delete the kube-registry pod so it picks up the new secret.
```shell
$ make deploy_secret
./do.sh deploy_secret
secret "azure-storage-key" configured
pod "kube-registry-2666010499-2t0gv" deleted
```

You can tunnel the remote registry to localhost:5000:
```shell
$ make tunnel
./do.sh tunnel
Forwarding from 127.0.0.1:5000 -> 5000
Forwarding from [::1]:5000 -> 5000

$ docker pull busybox
$ docker tag busybox localhost:5000/busybox
$ docker push localhost:5000/busybox
```

# Manual Deployment

## Create a kubernetes secret to provide your Storage Account credentials to the controller

The next step is to create a secret that will provide the StorageAccountName and the StorageAccountKey to your controller, whitout exposing anything in your YML.

To do that, you need to hash the StorageAccountKey and the StorageAccountName with a Base64

> You'll find that informations on the **Azure portal > Storage Account > Settings > Keys**

For example : 

```sh
$ echo "mystorageaccountname" | base64
bXlzdG9yYWdlYWNjb3VudG5hbWUK

$ echo "mystoragecontainername" | base64
bXlzdG9yYWdlY29udGFpbmVybmFtZQo=

$ echo "mystorageaccountkey" | base64
bXlzdG9yYWdlYWNjb3VudGtleQo=
``` 

Then you need to modify the **azure-storage-key-secret.yaml** by replacing the correct "base64 hash" with the corresponding key and name:

```
apiVersion: v1
kind: Secret
metadata:
  name: azure-storage-key
  namespace: kube-system
type: Opaque
data:
  storageaccount: <the base64 value of the first command> 
  storagecontainer: <the base64 value of the second command> 
  storagekey: <the base64 value of the third command>
```

The secret is ready to be deployed with the credentials of your own Azure Storage account.
You just need to deploy it inside of your Kubernetes cluster :

```
kubectl create -f ./azure-storage-key-secret.yaml
``` 

Note : By default the secret is deployed in the "kube-system" namespace as all components of that solution.

You can check the creation with that line :

```
kubectl get secrets --namespace="kube-system"
``` 

## Deploy your private registry with Azure Blob Storage

The solution is composed by three components :

- **kube-registry-deployment** (the Deployment for the docker registry container talking to Azure Blob Storage)
- **kube-registry-service** (the Service which exposes the registry container over the kubenertes cluster)
- **kube-registry-proxy** (the DaemonSet for the proxy which is forwarding the 5000 port to expose it as an HostPort on each nodes that makes the Registry server available on each node locally : localhost:5000/yourimage)

To deploy the Private Registry you just have to run :

```
kubectl create -f ./kube-registry-service.yaml
kubectl create -f ./kube-registry-deployment.yaml
kubectl create -f ./kube-registry-proxy.yaml
```

That will create a Deployment (ReplicaSet + Pod) / a Service and a DaemonSet for the registry proxy.

Anddddd that's it !

You're now able to test your Private Registry.

For example connect to one of your nodes or on the master by SSH and try that :

```
$ docker pull ubuntu 
$ docker tag ubuntu localhost:5000/ubuntu
$ docker push localhost:5000/ubuntu
``` 
You will able to push the Ubuntu image to your Azure Blob Storage !

## To go further 

You'r not always working or building your images on your kubernetes nodes or master and you'r right !

To be able to use that Private Registry from your workstation locally there is one solution :

First you need to retrieve the kube-registry POD :

``` 
kubectl get pods --namespace="kube-system"

for example found : kube-registry-v0-17vj5 in my cluster
```
Next you'll use the Port-forward kubectl command :

``` 
kubectl port-forward --namespace="kube-system" <theRegistryPOD> 5000:5000 &
```

That will map the local 5000 port to the 5000 port of your POD, so now you'r able on your local machine to do :

```
$ docker pull ubuntu 
$ docker tag ubuntu localhost:5000/ubuntu
$ docker push localhost:5000/ubuntu
``` 

As you did it on the Nodes !



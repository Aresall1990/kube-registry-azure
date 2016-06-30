# Kubernetes Private Registry with Azure

This repo contains a fully functionnal solution to deploy a **Private Docker Registry** within your **Kubernetes Cluster** using an **Azure Blob Storage** as backend.

# Creation of the Azure Storage account

To use the Azure Blob Storage as a Docker Registry, the first step is to create a Storage Account on your Azure Subscription.

> **Note:** The **Premium Storage Account** is not working for the moment with the Docker Registry. Only the Standard one.

You need to create that Storage Account in a separate "Ressource Group" than your Kubernetes cluster, to ensure the safety of your images.

# Create a kubernetes secret to provide your Storage Account credentials to the controller

The next step is to create a secret that will provide the StorageAccountName and the StorageAccountKey to your controller, whitout exposing anything in your YML.

To do that, you need to hash the StorageAccountKey and the StorageAccountName with a Base64

> You'll find that informations on the **Azure portal > Storage Account > Settings > Keys**

For example : 

```sh
$ echo "mystoragename" | base64
bXlzdG9yYWdlbmFtZQo=
$ echo "mystorageaccountkey" | base64
bXlzdG9yYWdlYWNjb3VudGtleQo=
``` 

Then you will modify the **azure-storage-credentials.yml** by replacing the correct "base64 hash" with the corresponding key and name:

```
apiVersion: v1
kind: Secret
metadata:
  name: azure-storage-key
  namespace: kube-system
type: Opaque
data:
  storagename: <the base64 hash of the first command> 
  storagekey: <the base64 hash of the second command>
```

The secret is ready to be deployed with the credentials of your own Azure Storage account.
You just need to deploy it inside of your Kubernetes cluster :

```
kubectl create -f ./azure-storage-credentials.yml
``` 

Note : By default the secret is deployed in the "kube-system" namespace as all components of that solution.

You can check the creation with that line :

```
kubectl get secrets --namespace="kube-system"
``` 

# Deploy your private registry with Azure Blob Storage

The solution is composed by three components :

- **kube-registry-controller** (witch is the POD who communicate with the Azure Blob Storage)
- **kube-registry-service** (expose the registry controller over the kubenertes cluster)
- **kube-registry-proxy** (the proxy is forwarding the 5000 port to expose it as an HostPort on each nodes that makes the Registry server available on each node locally : localhost:5000/yourimage)

To deploy the Private Registry you just have to run :

```
kubectl create -f ./kube-registry-controller.yml
kubectl create -f ./kube-registry-service.yml
kubectl create -f ./kube-registry-proxy.yml
```

That will create a POD / a SERVICE and a DaemonSet for the registry proxy.

Anddddd that's it !

You'r now able to test your Private Registry.

For example connect to one of your nodes or on the master by SSH and try that :

```
$ docker pull ubuntu 
$ docker tag ubuntu localhost:5000/ubuntu
$ docker push localhost:5000/ubuntu
``` 
You will able to push the Ubuntu image to your Azure Blob Storage !

# To go further 

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



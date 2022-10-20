az group create -n akstlstest -l centralus
az aks create -g akstlstest -n akstlstest
az acr create -n akstlstest -g akstlstest --sku basic
az aks update -n akstlstest -g akstlstest --attach-acr akstlstest

REGISTRY_NAME="akstlstest"
CERT_MANAGER_REGISTRY=quay.io
CERT_MANAGER_TAG=v1.10.0
CERT_MANAGER_IMAGE_CONTROLLER=jetstack/cert-manager-controller
CERT_MANAGER_IMAGE_WEBHOOK=jetstack/cert-manager-webhook
CERT_MANAGER_IMAGE_CAINJECTOR=jetstack/cert-manager-cainjector
az acr import --name $REGISTRY_NAME --source $CERT_MANAGER_REGISTRY/$CERT_MANAGER_IMAGE_CONTROLLER:$CERT_MANAGER_TAG --image $CERT_MANAGER_IMAGE_CONTROLLER:$CERT_MANAGER_TAG
az acr import --name $REGISTRY_NAME --source $CERT_MANAGER_REGISTRY/$CERT_MANAGER_IMAGE_WEBHOOK:$CERT_MANAGER_TAG --image $CERT_MANAGER_IMAGE_WEBHOOK:$CERT_MANAGER_TAG
az acr import --name $REGISTRY_NAME --source $CERT_MANAGER_REGISTRY/$CERT_MANAGER_IMAGE_CAINJECTOR:$CERT_MANAGER_TAG --image $CERT_MANAGER_IMAGE_CAINJECTOR:$CERT_MANAGER_TAG

az aks get-credentials -g akstlstest -n akstlstest

helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

DNS_LABEL="akstlstest"
NAMESPACE="ingress-basic"

helm install ingress-nginx ingress-nginx/ingress-nginx \
  --create-namespace \
  --namespace $NAMESPACE \
  --set controller.service.annotations."service\.beta\.kubernetes\.io/azure-load-balancer-health-probe-request-path"=/healthz \
  --set controller.service.annotations."service\.beta\.kubernetes\.io/azure-dns-label-name"=$DNS_LABEL

ACR_URL=${REGISTRY_NAME}.azurecr.io
kubectl label namespace ingress-basic cert-manager.io/disable-validation=true
helm repo add jetstack https://charts.jetstack.io
helm repo update

helm install cert-manager jetstack/cert-manager \
  --namespace $NAMESPACE \
  --set installCRDs=true \
  --set image.repository=$ACR_URL/jetstack/cert-manager-controller \
  --set image.tag=$CERT_MANAGER_TAG \
  --set webhook.image.repository=$ACR_URL/jetstack/cert-manager-webhook \
  --set webhook.image.tag=$CERT_MANAGER_TAG \
  --set cainjector.image.repository=$ACR_URL/jetstack/cert-manager-cainjector \
  --set cainjector.image.tag=$CERT_MANAGER_TAG


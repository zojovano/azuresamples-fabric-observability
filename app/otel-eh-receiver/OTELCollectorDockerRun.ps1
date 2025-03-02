#docker pull otel/opentelemetry-collector-contrib:latest

docker build -t otel-collector:latest .

# docker run otel/opentelemetry-collector-contrib:latest
#docker run -v ${pwd}\otel-collector.yaml:/etc/otelcol-contrib/config.yaml otel/opentelemetry-collector-contrib:latest
docker run --rm otel-collector:latest

# push to azure container registry
az login

az acr login --name demofabricmonitoring

docker build -t demofabricmonitoring.azurecr.io/otel-collector:latest .

docker push demofabricmonitoring.azurecr.io/otel-collector:latest
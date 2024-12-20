docker pull otel/opentelemetry-collector-contrib:latest
# docker run otel/opentelemetry-collector-contrib:latest
docker run -v $(pwd)/otel-collector.yaml:/etc/otelcol-contrib/config.yaml otel/opentelemetry-collector-contrib:latest

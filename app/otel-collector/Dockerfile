# See https://aka.ms/customizecontainer to learn how to customize your debug container and how Visual Studio uses this Dockerfile to build your images for faster debugging.

# This stage is used when running from VS in fast mode (Default for Debug configuration)
FROM otel/opentelemetry-collector-contrib:latest

# Copy the config file into the container
COPY config.yaml /etc/otel/config.yaml

# docker pull otel/opentelemetry-collector-contrib:0.116.1

ENTRYPOINT ["/otelcol-contrib"]

# Set the command to run the OpenTelemetry Collector with the config file
CMD ["--config", "/etc/otel/config.yaml"]
EXPOSE 4317/tcp 4318/tcp 55678/tcp 55679/tcp

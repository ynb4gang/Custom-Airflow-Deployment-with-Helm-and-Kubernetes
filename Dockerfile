# Use the official Apache Airflow image as the base
FROM apache/airflow:2.7.3

# Set the maintainer label
LABEL maintainer="Airflow-Custom-Image"

# Switch to root user to install system dependencies
USER root

# Install Java (required for Spark)
RUN apt-get update \
  && apt-get install -y --no-install-recommends \
         openjdk-11-jre-headless \
  && apt-get autoremove -yqq --purge \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

# Switch back to the airflow user
USER airflow

# Copy the requirements file into the image
COPY requirements.txt .

# Install Python packages from requirements.txt
RUN pip install -r requirements.txt

# Set the JAVA_HOME environment variable
ENV JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64

# Install Apache Airflow and the Spark provider
RUN pip install --no-cache-dir "apache-airflow==${AIRFLOW_VERSION}" apache-airflow-providers-apache-spark==2.1.3

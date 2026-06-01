FROM ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive
ARG VERILATOR_REF=v5.048

RUN apt-get update && apt-get install -y \
    git \
    curl \
    ca-certificates \
    help2man \
    perl \
    python3 \
    python3-pip \
    python3-venv \
    make \
    autoconf \
    g++ \
    flex \
    bison \
    ccache \
    libfl2 \
    libfl-dev \
    zlib1g \
    zlib1g-dev \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Build known-good Verilator from source instead of using apt verilator.
RUN git clone https://github.com/verilator/verilator.git /opt/verilator-src && \
    cd /opt/verilator-src && \
    git checkout ${VERILATOR_REF} && \
    autoconf && \
    ./configure && \
    make -j"$(nproc)" && \
    make install && \
    cd / && \
    rm -rf /opt/verilator-src

# Install common Python HDL tooling.
RUN python3 -m venv /opt/socet-venv && \
    /opt/socet-venv/bin/pip install --upgrade pip && \
    /opt/socet-venv/bin/pip install fusesoc edalize pyyaml

ENV PATH="/opt/socet-venv/bin:${PATH}"

ENV PYTHONPATH=""
WORKDIR /work

CMD ["/bin/bash"]

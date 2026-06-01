FROM ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive
ARG VERILATOR_REF=v5.048
ARG VERIBLE_VERSION=v0.0-4023-gc1271a00
ARG SV2V_VERSION=v0.0.12

RUN apt-get update && apt-get install -y \
    git \
    curl \
    unzip \
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
    yosys \
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

# Install Verible from CHIPS Alliance release.
RUN curl -L -o /tmp/verible.tar.gz \
    "https://github.com/chipsalliance/verible/releases/download/${VERIBLE_VERSION}/verible-${VERIBLE_VERSION}-linux-static-x86_64.tar.gz" && \
    mkdir -p /opt/verible && \
    tar -xzf /tmp/verible.tar.gz -C /opt/verible --strip-components=1 && \
    rm /tmp/verible.tar.gz

# Install sv2v from release binary.
RUN curl -L -o /tmp/sv2v.zip \
    "https://github.com/zachjs/sv2v/releases/download/${SV2V_VERSION}/sv2v-Linux.zip" && \
    unzip /tmp/sv2v.zip -d /opt/sv2v && \
    rm /tmp/sv2v.zip && \
    chmod +x /opt/sv2v/sv2v

# Install common Python HDL tooling in a venv.
RUN python3 -m venv /opt/socet-venv && \
    /opt/socet-venv/bin/pip install --upgrade pip && \
    /opt/socet-venv/bin/pip install fusesoc edalize pyyaml

ENV PATH="/opt/sv2v:/opt/verible/bin:/opt/socet-venv/bin:${PATH}"
ENV PYTHONPATH=""

WORKDIR /work

CMD ["/bin/bash"]
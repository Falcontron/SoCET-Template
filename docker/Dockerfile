FROM ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive
ARG VERILATOR_REF=v5.048
ARG VERIBLE_VERSION=v0.0-4023-gc1271a00
ARG SV2V_REF=v0.0.13

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
    ghc \
    cabal-install \
    alex \
    happy \
    cmake \
    swig \
    tcl-dev \
    libreadline-dev \
    libeigen3-dev \
    libgtest-dev \
    libcudd-dev \
    && rm -rf /var/lib/apt/lists/*

# Build OpenSTA from source first so OpenSTA failures appear early.
RUN git clone --recursive https://github.com/The-OpenROAD-Project/OpenSTA.git /opt/OpenSTA-src && \
    cd /opt/OpenSTA-src && \
    mkdir -p build && \
    cd build && \
    cmake .. && \
    make VERBOSE=1 -j"$(nproc)" && \
    make install && \
    command -v sta && \
    sta -version && \
    cd / && \
    rm -rf /opt/OpenSTA-src

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
    chmod -R a+rX /opt/verible && \
    rm /tmp/verible.tar.gz

# Install Rust and svlint using rustup to avoid old Ubuntu rustc/cargo versions.
ENV CARGO_HOME=/opt/cargo
ENV RUSTUP_HOME=/opt/rustup
ENV PATH="/opt/cargo/bin:${PATH}"

RUN curl https://sh.rustup.rs -sSf | sh -s -- -y --profile minimal && \
    cargo install svlint --locked && \
    cp /opt/cargo/bin/svlint /usr/local/bin/svlint && \
    svlint --version && \
    rm -rf /opt/cargo/registry /opt/cargo/git

# Build sv2v from source.
RUN git clone https://github.com/zachjs/sv2v.git /opt/sv2v-src && \
    cd /opt/sv2v-src && \
    git checkout ${SV2V_REF} && \
    cabal update && \
    cabal build && \
    mkdir -p /opt/sv2v/bin && \
    cp "$(find dist-newstyle -type f -name sv2v | head -n 1)" /opt/sv2v/bin/sv2v && \
    chmod +x /opt/sv2v/bin/sv2v && \
    cd / && \
    rm -rf /opt/sv2v-src /root/.cabal /root/.ghc

# Install common Python HDL tooling in a venv.
RUN python3 -m venv /opt/socet-venv && \
    /opt/socet-venv/bin/pip install --upgrade pip && \
    /opt/socet-venv/bin/pip install fusesoc edalize pyyaml

ENV PATH="/opt/sv2v/bin:/opt/verible/bin:/opt/cargo/bin:/opt/socet-venv/bin:${PATH}"
ENV PYTHONPATH=""

WORKDIR /work

CMD ["/bin/bash"]

# opensta for timing and power, svlint and verible
# pruduce an executable thats downloadable as an artifact
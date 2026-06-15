FROM ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive
ARG VERILATOR_REF=v5.048
ARG VERIBLE_VERSION=v0.0-4023-gc1271a00
ARG SV2V_REF=v0.0.13

# xPack GNU RISC-V Embedded GCC.
#
# RISCVBusiness uses RISC-V bare-metal tests, so the CI image needs a
# RISC-V cross compiler. The xPack toolchain is a portable prebuilt
# toolchain, which keeps the Docker image reproducible.
#
# v14.2.0-3 is pinned because it includes useful RV32 multilib support,
# including rv32imc/ilp32.
ARG RISCV_XPACK_VERSION=14.2.0-3
ARG RISCV_XPACK_ARCHIVE=xpack-riscv-none-elf-gcc-14.2.0-3-linux-x64.tar.gz
ARG RISCV_XPACK_URL=https://github.com/xpack-dev-tools/riscv-none-elf-gcc-xpack/releases/download/v14.2.0-3/xpack-riscv-none-elf-gcc-14.2.0-3-linux-x64.tar.gz

RUN apt-get update && apt-get install -y \
    git \
    curl \
    unzip \
    ca-certificates \
    xz-utils \
    file \
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
    autoconf \
    automake \
    libtool \
    m4 \
    && rm -rf /var/lib/apt/lists/*

# Install xPack RISC-V GCC.
#
# xPack names its binaries riscv-none-elf-*.
# Many RISC-V test flows expect riscv64-unknown-elf-*.
# Add compatibility symlinks so both conventions work.
RUN curl -L --fail --retry 3 --retry-delay 2 -o "/tmp/${RISCV_XPACK_ARCHIVE}" "${RISCV_XPACK_URL}" && \
    mkdir -p /opt/riscv && \
    tar -xzf "/tmp/${RISCV_XPACK_ARCHIVE}" -C /opt/riscv --strip-components=1 && \
    rm -f "/tmp/${RISCV_XPACK_ARCHIVE}" && \
    chmod -R a+rX /opt/riscv && \
    ln -sf /opt/riscv/bin/riscv-none-elf-addr2line /usr/local/bin/riscv64-unknown-elf-addr2line && \
    ln -sf /opt/riscv/bin/riscv-none-elf-ar        /usr/local/bin/riscv64-unknown-elf-ar && \
    ln -sf /opt/riscv/bin/riscv-none-elf-as        /usr/local/bin/riscv64-unknown-elf-as && \
    ln -sf /opt/riscv/bin/riscv-none-elf-c++       /usr/local/bin/riscv64-unknown-elf-c++ && \
    ln -sf /opt/riscv/bin/riscv-none-elf-c++filt   /usr/local/bin/riscv64-unknown-elf-c++filt && \
    ln -sf /opt/riscv/bin/riscv-none-elf-cpp       /usr/local/bin/riscv64-unknown-elf-cpp && \
    ln -sf /opt/riscv/bin/riscv-none-elf-elfedit   /usr/local/bin/riscv64-unknown-elf-elfedit && \
    ln -sf /opt/riscv/bin/riscv-none-elf-g++       /usr/local/bin/riscv64-unknown-elf-g++ && \
    ln -sf /opt/riscv/bin/riscv-none-elf-gcc       /usr/local/bin/riscv64-unknown-elf-gcc && \
    ln -sf /opt/riscv/bin/riscv-none-elf-gcc-ar    /usr/local/bin/riscv64-unknown-elf-gcc-ar && \
    ln -sf /opt/riscv/bin/riscv-none-elf-gcc-nm    /usr/local/bin/riscv64-unknown-elf-gcc-nm && \
    ln -sf /opt/riscv/bin/riscv-none-elf-gcc-ranlib /usr/local/bin/riscv64-unknown-elf-gcc-ranlib && \
    ln -sf /opt/riscv/bin/riscv-none-elf-gcov      /usr/local/bin/riscv64-unknown-elf-gcov && \
    ln -sf /opt/riscv/bin/riscv-none-elf-gcov-dump /usr/local/bin/riscv64-unknown-elf-gcov-dump && \
    ln -sf /opt/riscv/bin/riscv-none-elf-gcov-tool /usr/local/bin/riscv64-unknown-elf-gcov-tool && \
    ln -sf /opt/riscv/bin/riscv-none-elf-gdb       /usr/local/bin/riscv64-unknown-elf-gdb && \
    ln -sf /opt/riscv/bin/riscv-none-elf-gprof     /usr/local/bin/riscv64-unknown-elf-gprof && \
    ln -sf /opt/riscv/bin/riscv-none-elf-ld        /usr/local/bin/riscv64-unknown-elf-ld && \
    ln -sf /opt/riscv/bin/riscv-none-elf-ld.bfd    /usr/local/bin/riscv64-unknown-elf-ld.bfd && \
    ln -sf /opt/riscv/bin/riscv-none-elf-nm        /usr/local/bin/riscv64-unknown-elf-nm && \
    ln -sf /opt/riscv/bin/riscv-none-elf-objcopy   /usr/local/bin/riscv64-unknown-elf-objcopy && \
    ln -sf /opt/riscv/bin/riscv-none-elf-objdump   /usr/local/bin/riscv64-unknown-elf-objdump && \
    ln -sf /opt/riscv/bin/riscv-none-elf-ranlib    /usr/local/bin/riscv64-unknown-elf-ranlib && \
    ln -sf /opt/riscv/bin/riscv-none-elf-readelf   /usr/local/bin/riscv64-unknown-elf-readelf && \
    ln -sf /opt/riscv/bin/riscv-none-elf-size      /usr/local/bin/riscv64-unknown-elf-size && \
    ln -sf /opt/riscv/bin/riscv-none-elf-strings   /usr/local/bin/riscv64-unknown-elf-strings && \
    ln -sf /opt/riscv/bin/riscv-none-elf-strip     /usr/local/bin/riscv64-unknown-elf-strip && \
    /opt/riscv/bin/riscv-none-elf-gcc --version && \
    riscv64-unknown-elf-gcc --version

# Build CUDD from source for OpenSTA.
RUN git clone https://github.com/ivmai/cudd.git /opt/cudd-src && \
    cd /opt/cudd-src && \
    autoreconf -fiv && \
    ./configure --prefix=/opt/cudd --enable-shared --enable-obj && \
    make -j"$(nproc)" && \
    make install && \
    cd / && \
    rm -rf /opt/cudd-src

# Make CUDD shared libraries visible to OpenSTA at runtime.
RUN echo "/opt/cudd/lib" > /etc/ld.so.conf.d/cudd.conf && ldconfig

# Build OpenSTA from source first so OpenSTA failures appear early.
RUN git clone --recursive https://github.com/The-OpenROAD-Project/OpenSTA.git /opt/OpenSTA-src && \
    cd /opt/OpenSTA-src && \
    mkdir -p build && \
    cd build && \
    cmake .. \
        -DCUDD_INCLUDE_DIR=/opt/cudd/include \
        -DCUDD_LIB=/opt/cudd/lib/libcudd.so && \
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

ENV PATH="/opt/riscv/bin:/opt/sv2v/bin:/opt/verible/bin:/opt/cargo/bin:/opt/socet-venv/bin:${PATH}"
ENV PYTHONPATH=""

WORKDIR /work

CMD ["/bin/bash"]

# opensta for timing and power, svlint and verible
# pruduce an executable thats downloadable as an artifact
# syntax=docker/dockerfile:1.4
FROM amd64/archlinux:latest AS builder
ENV LANG C.UTF-8

WORKDIR /workspace

RUN \
  pacman -Syu --noconfirm base-devel bison boost cmake \
    curl extra-cmake-modules flex fmt git glibmm-2.68 \
    gobject-introspection hicolor-icon-theme hunspell \
    jemalloc kcoreaddons5 libdispatch libnotify \
    libxcomposite libxrandr libxtst microsoft-gsl \
    minizip ninja openal opus pipewire pulseaudio python \
    qt5-base qt5-svg qt5-wayland range-v3 tl-expected \
    wget xdg-desktop-portal xxhash yasm

FROM builder AS staticdeps
ENV DESTDIR /abdist
ENV CFLAGS '-flto'
ENV LDFLAGS '-flto -fuse-linker-plugin'
ENV AR gcc-ar
ENV LANG C.UTF-8

RUN pacman -Syu --noconfirm meson nasm python-setuptools

RUN wget https://github.com/abseil/abseil-cpp/archive/refs/tags/20230802.1.tar.gz

RUN wget https://github.com/webmproject/libvpx/archive/v1.13.1/libvpx-1.13.1.tar.gz

RUN wget https://github.com/protocolbuffers/protobuf/archive/refs/tags/v4.25.1.tar.gz

RUN tar pxf libvpx-1.13.1.tar.gz && \
  cd libvpx-1.13.1 && \
  ./configure --prefix=/usr \
    --libdir=/usr/lib \
    --enable-runtime-cpu-detect \
    --enable-pic \
    --enable-vp8 \
    --enable-vp9-decoder \
    --enable-vp9-encoder \
    --enable-vp9-highbitdepth \
    --enable-vp9-temporal-denoising \
    --enable-postproc \
    --enable-experimental \
    --disable-avx512 \
    --disable-shared \
    --disable-install-srcs \
    --disable-unit-tests \
    --disable-decode-perf-tests \
    --disable-encode-perf-tests && \
  make -j$(nproc) HAVE_GNU_STRIP=no && \
  make install

RUN cp -a /abdist/usr /

RUN wget https://github.com/cisco/openh264/archive/refs/tags/v2.4.0.tar.gz

RUN tar pxf v2.4.0.tar.gz && \
  cd openh264-2.4.0 && \
  mkdir abbuild && \
  cd abbuild && \
  meson setup .. --default-library static \
    --prefix /usr \
    --optimization 3 && \
  ninja install

RUN git clone https://gitlab.xiph.org/xiph/rnnoise --depth=1 && \
  cd rnnoise && \
  ./autogen.sh && \
  ./configure --prefix=/usr --enable-shared=no && \
  make install

RUN tar pxf v4.25.1.tar.gz && \
  tar pxf 20230802.1.tar.gz && \
  cd protobuf-4.25.1 && \
  cp -a ../abseil-cpp-20230802.1/* \
  third_party/abseil-cpp/ && \
  cmake . -GNinja \
    -Dprotobuf_ABSL_PROVIDER=module \
    -Dprotobuf_BUILD_TESTS=OFF \
    -Dprotobuf_BUILD_CONFORMANCE=OFF \
    -Dprotobuf_BUILD_EXAMPLES=ON \
    -Dprotobuf_BUILD_PROTOC_BINARIES=ON \
    -Dprotobuf_BUILD_SHARED_LIBS=OFF \
    -Dprotobuf_MSVC_STATIC_RUNTIME=OFF \
    -DCMAKE_INSTALL_PREFIX=/usr && \
  ninja install

RUN wget https://ffmpeg.org/releases/ffmpeg-6.1.tar.xz

RUN tar pxf ffmpeg-6.1.tar.xz && \
  cd ffmpeg-6.1 && \
  ./configure --prefix=/usr \
    --enable-lto \
    --disable-shared \
    --enable-libvpx && \
  make -j$(nproc) install

FROM builder
ENV LANG C.UTF-8

COPY --link --from=staticdeps /abdist/usr /usr

LABEL org.opencontainers.image.source=https://github.com/chenx97/telegram-qt5-testing

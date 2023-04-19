FROM --platform=$BUILDPLATFORM archlinux:base as ground

ARG TARGETPLATFORM
ARG BUILDPLATFORM

ARG BUILD_DATE
ARG VCS_REF
ARG VCS_URL
ARG VERSION
ARG TIMEZONE

# USER root

# Add "app" user with "sudo" access
RUN pacman -Syu --noconfirm \
    && pacman -S --noconfirm --needed sudo \
    && useradd -m -G wheel -s /bin/bash app \
    && sed -i 's/# %wheel ALL=(ALL:ALL) NOPASSWD: ALL/%wheel ALL=(ALL:ALL) NOPASSWD: ALL/' /etc/sudoers \
    && sed -i 's/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

USER app

WORKDIR /tmp

# Update pacman database and install yay helper
RUN sudo pacman -Syu --noconfirm \
    && sudo pacman -S --noconfirm --needed git base-devel \
    && git clone https://aur.archlinux.org/yay-bin.git \
    && cd yay-bin \
    && makepkg -si --needed --noconfirm \
    && cd .. && rm -rf -- yay-bin

# ------- {{ ground.end }}

FROM ground as base

RUN yay -Syu --noconfirm \
    && yay -S --noconfirm --removemake --needed \
        mediainfo ffmpeg-full libvpx mkvtoolnix-cli aom-av1-lavish-git svt-av1 \
        vapoursynth ffms2 vapoursynth-plugin-lsmashsource vmaf \
        glslang vulkan-icd-loader vulkan-headers \

ENV PYTHONPATH=$(python -c "import os;print(os.path.dirname(os.__file__))")

# ------- {{ base.end }}

FROM base AS build-plugins

RUN yay -Syu --noconfirm \
    && yay -S --noconfirm --removemake --needed vapoursynth \
        glslang vulkan-icd-loader vulkan-headers \
        vapoursynth-plugin-adaptivegrain-git \
        vapoursynth-plugin-assrender-git \
        vapoursynth-plugin-bestaudiosource-git \
        vapoursynth-plugin-bm3d-git \
        vapoursynth-plugin-deblock-git \
        vapoursynth-plugin-edi_rpow2-git \
        vapoursynth-plugin-f3kdb-git \
        vapoursynth-plugin-fluxsmooth-git \
        vapoursynth-plugin-fmtconv-git \
        vapoursynth-plugin-fvsfunc-git \
        vapoursynth-plugin-havsfunc-git \
        vapoursynth-plugin-hqdn3d-git \
        vapoursynth-plugin-imwri-git \
        vapoursynth-plugin-kagefunc-git \
        vapoursynth-plugin-knlmeanscl-git \
        vapoursynth-plugin-muvsfunc-git \
        vapoursynth-plugin-mvsfunc-git \
        vapoursynth-plugin-mvtools-git \
        vapoursynth-plugin-nlm-git \
        vapoursynth-plugin-nnedi3-git \
        vapoursynth-plugin-placebo-git \
        vapoursynth-plugin-vaguedenoiser-git \
        vapoursynth-plugin-vmaf-git \
        vapoursynth-plugin-vsaa-git \
        vapoursynth-plugin-vsdeband-git \
        vapoursynth-plugin-vsdehalo-git \
        vapoursynth-plugin-vskernels-git \
        vapoursynth-plugin-vsdenoise-git \
        vapoursynth-plugin-vsscale-git \
        vapoursynth-plugin-vsutil-git \
        vapoursynth-plugin-xaa-git \
        vapoursynth-plugin-waifu2x-ncnn-vulkan-git \
        vapoursynth-plugin-znedi3-git \
        vapoursynth-tools-getnative-git \
    && sudo mkdir -p /site-packages && sudo chown -R app /site-packages \
    && find ${PYTHONPATH}/site-packages -maxdepth 1 -name "*.py" -type f | xargs -i cp -f {} /site-packages/ \
    && find ${PYTHONPATH}/site-packages -maxdepth 1 -name "vsutil" -type d | xargs -i cp -rf {} /site-packages/

# ------- {{ build-plugins.end }}

FROM base AS build-base

# Install dependancies needed by build steps
RUN yay -S --noconfirm --needed rust clang nasm git

RUN cargo install cargo-chef

# ------- {{ build-base.end }}

FROM build-base AS planner

RUN git clone --filter=blob:none https://github.com/master-of-zen/Av1an /tmp/Av1an

RUN cargo chef prepare

# ------- {{ planner.end }}

FROM build-base AS build

# Prepare Av1an recipe
COPY --from=planner /tmp/Av1an/recipe.json recipe.json
RUN cargo chef cook --release

# Compile rav1e from git, as archlinux is still on rav1e 0.6.3
RUN git clone --filter=blob:none https://github.com/xiph/rav1e \
    && cd rav1e \
    && cargo build --release \
    && strip ./target/release/rav1e \
    && mv ./target/release/rav1e /usr/local/bin \
    && cd .. && rm -rf ./rav1e

# Build av1an
RUN git clone --filter=blob:none https://master-of-zen/Av1an /tmp/Av1an

RUN cargo build --release \
    && mv ./target/release/av1an /usr/local/bin \
    && cd .. && rm -rf ./Av1an


# ------- {{ build.end }}

FROM base AS runtime

LABEL org.label-schema.build-date=$BUILD_DATE \
    org.label-schema.name="VapourSynth-Av1an" \
    org.label-schema.description="Docker Images for Av1an with VapourSynth support" \
    org.label-schema.url="https://rokibhasansagar.github.io" \
    org.label-schema.vcs-ref=$VCS_REF \
    org.label-schema.vcs-url=$VCS_URL \
    org.label-schema.vendor="Rokib Hasan Sagar" \
    org.label-schema.version=$VERSION \
    org.label-schema.schema-version="1.0"

LABEL maintainer="fr3akyphantom <rokibhasansagar2014@outlook.com>"

COPY --from=build /usr/local/bin/rav1e /usr/local/bin/rav1e
COPY --from=build /usr/local/bin/av1an /usr/local/bin/av1an
COPY --from=build-plugins /site-packages ${PYTHONPATH}/site-packages/
COPY --from=build-plugins /usr/lib/vapoursynth /usr/lib/vapoursynth

VOLUME ["/videos"]
WORKDIR /videos

# ENTRYPOINT [ "/usr/local/bin/av1an" ]
ENTRYPOINT [ "/usr/bin/bash" ]

FROM archlinux:base-devel as ground

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
    && sudo pacman -S --noconfirm --needed git \
    && git clone https://aur.archlinux.org/yay-bin.git \
    && cd yay-bin \
    && makepkg -si --needed --noconfirm \
    && cd .. && rm -rf -- yay-bin \
    && git clone https://aur.archlinux.org/paru-bin.git \
    && cd paru-bin \
    && makepkg -si --needed --noconfirm \
    && cd .. && rm -rf -- paru-bin

# ------- {{ ground.end }}

FROM ground as base

RUN yay -Syu --noconfirm \
    && yay -S --noconfirm --nouseask --noprovides --removemake --cleanafter \
        --answerclean NotInstalled --answerdiff None --needed --batchinstall --combinedupgrade \
        tesseract-data-eng tesseract-data-jpn highway-git libjxl-metrics-git &>/dev/null \
    && yay -Syu --noconfirm \
    && yay -S --noconfirm --nouseask --noprovides --removemake --cleanafter \
        --answerclean NotInstalled --answerdiff None --needed --batchinstall --combinedupgrade \
        aom-av1-lavish-git &>/dev/null \
    && yay -S --noconfirm --nouseask --noprovides --removemake --cleanafter \
        --answerclean NotInstalled --answerdiff None --needed --batchinstall --combinedupgrade \
        mediainfo ffmpeg vapoursynth ffms2 libvpx mkvtoolnix-cli svt-av1 vapoursynth-plugin-lsmashsource python-pip &>/dev/null

# ------- {{ base.end }}

FROM base AS build-plugins

RUN yay -Syu --noconfirm \
    && yay -S --noconfirm --nouseask --noprovides --removemake --cleanafter \
        --answerclean NotInstalled --answerdiff None --needed --batchinstall --combinedupgrade \
        vapoursynth-plugin-fmtconv-git vapoursynth-plugin-deblock-git \
    && yay -S --noconfirm --nouseask --noprovides --removemake --cleanafter \
        --answerclean NotInstalled --answerdiff None --needed --batchinstall --combinedupgrade \
        vapoursynth-plugin-lsmashsource \
        glslang vulkan-icd-loader vulkan-headers \
        vapoursynth-plugin-adaptivegrain-git \
        vapoursynth-plugin-assrender-git \
        vapoursynth-plugin-bestaudiosource-git \
        vapoursynth-plugin-bm3d-git \
        vapoursynth-plugin-edi_rpow2-git \
        vapoursynth-plugin-f3kdb-git \
        vapoursynth-plugin-fvsfunc-git \
        vapoursynth-plugin-havsfunc-git \
        vapoursynth-plugin-hqdn3d-git \
        vapoursynth-plugin-imwri-git \
        vapoursynth-plugin-kagefunc-git \
        vapoursynth-plugin-knlmeanscl-git \
        vapoursynth-plugin-muvsfunc-git \
        vapoursynth-plugin-mvsfunc-git \
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
        vapoursynth-tools-getnative-git

RUN sudo mkdir -p /site-packages && sudo chown -R app /site-packages \
    && sudo mkdir -p /vapour-docs && sudo chown -R app /vapour-docs \
    && find "$(python -c "import os;print(os.path.dirname(os.__file__))")" -depth -type d -name __pycache__ -exec sudo rm -rf '{}' + \
    && find "$(python -c "import os;print(os.path.dirname(os.__file__))")"/site-packages -maxdepth 1 -name "*.py" -type f | xargs -i cp -f {} /site-packages/ \
    && find "$(python -c "import os;print(os.path.dirname(os.__file__))")"/site-packages -maxdepth 1 -name "vsutil" -type d | xargs -i cp -rf {} /site-packages/ \
    && find /usr/share/doc/vapoursynth -maxdepth 3 \( -iname "README.rst" -or -iname "README.md" -or -iname "README.html" \) -type f -exec cp -a -rf --parent {} /vapour-docs/ \;

# ------- {{ build-plugins.end }}

FROM base AS build-base

# Install dependancies needed by build steps
RUN yay -S --noconfirm --nouseask --noprovides --removemake --cleanafter \
        --answerclean NotInstalled --answerdiff None --needed --batchinstall --combinedupgrade \
        rust clang nasm git &>/dev/null

RUN cargo install cargo-chef

WORKDIR /tmp/Av1an

# ------- {{ build-base.end }}

FROM build-base AS planner

RUN git clone --filter=blob:none https://github.com/master-of-zen/Av1an /tmp/Av1an

RUN cargo chef prepare

# ------- {{ planner.end }}

FROM build-base AS build

WORKDIR /tmp

# Compile rav1e from git, as archlinux is still on rav1e 0.6.3
RUN git clone --filter=blob:none https://github.com/xiph/rav1e \
    && cd rav1e \
    && cargo build --release \
    && strip ./target/release/rav1e \
    && sudo mv ./target/release/rav1e /usr/local/bin \
    && cd .. && rm -rf ./rav1e

WORKDIR /tmp/Av1an

# Prepare Av1an recipe
COPY --from=planner /tmp/Av1an/recipe.json recipe.json

RUN cargo chef cook --release

# Build av1an
RUN cargo build --release \
    && sudo mv ./target/release/av1an /usr/local/bin \
    && cd .. && rm -rf ./Av1an

# ------- {{ build.end }}

FROM base AS runtime

LABEL org.label-schema.name="VapourSynth-Av1an" \
    org.label-schema.description="Docker Images for Av1an with VapourSynth support" \
    org.label-schema.vendor="Rokib Hasan Sagar" \
    org.label-schema.version="1.0" \
    org.label-schema.schema-version="1.0"

LABEL maintainer="fr3akyphantom <rokibhasansagar2014@outlook.com>"

COPY --from=build /usr/local/bin/rav1e /usr/local/bin/rav1e
COPY --from=build /usr/local/bin/av1an /usr/local/bin/av1an
COPY --from=build-plugins /site-packages /tmp/site-packages/
COPY --from=build-plugins /vapour-docs /tmp/vapour-docs/
COPY --from=build-plugins /usr/lib/vapoursynth /usr/lib/vapoursynth

RUN cp -rf /tmp/vapour-docs/usr/share/doc/vapoursynth/* /usr/share/doc/vapoursynth/ \
    && cp -rf /tmp/site-packages/* "$(python -c "import os;print(os.path.dirname(os.__file__))")"/site-packages/ \
    && find "$(python -c "import os;print(os.path.dirname(os.__file__))")" -depth -type d -name __pycache__ -exec sudo rm -rf '{}' + \
    && sudo rm -rf /tmp/*

VOLUME ["/videos"]
WORKDIR /videos

# ENTRYPOINT [ "/usr/local/bin/av1an" ]
ENTRYPOINT [ "/usr/bin/bash" ]

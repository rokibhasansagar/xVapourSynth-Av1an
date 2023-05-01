# syntax=docker/dockerfile:1.5
FROM archlinux:base-devel

# USER root

SHELL ["/bin/bash", "-c"]

# Add "app" user with "sudo" access
RUN <<-'EOL'
	useradd -m -G wheel -s /bin/bash app
	sed -i 's/# %wheel ALL=(ALL:ALL) NOPASSWD: ALL/%wheel ALL=(ALL:ALL) NOPASSWD: ALL/' /etc/sudoers
	sed -i 's/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers
EOL

USER app

WORKDIR /tmp

# Update pacman database and install yay and paru helpers
RUN <<-'EOL'
	set -ex
	sudo pacman -Syu --noconfirm 2>/dev/null
	echo -e "[+] List of PreInstalled Packages:"
	echo -e "$(sudo pacman -Q | awk '{print $1}' | sed -z 's/\n/ /g;s/\s$/\n/g')" 2>/dev/null
	echo -e "[+] Installing yay-bin & paru-bin (pacman helpers)"
	sudo pacman -Syu --noconfirm && sudo pacman -S --noconfirm --needed git
	for app in yay-bin paru-bin; do
	  git clone -q https://aur.archlinux.org/${app}.git
	  cd ./${app} && makepkg -si --noconfirm --noprogressbar --clean --needed
	  cd .. && rm -rf -- ./${app}
	done
	echo -e "[+] List of Packages Before Actual Operation:"
	echo -e "$(sudo pacman -Q | awk '{print $1}' | sed -z 's/\n/ /g;s/\s$/\n/g')" 2>/dev/null
	export PARU_OPTS="--skipreview --noprovides --removemake --cleanafter --useask --combinedupgrade --batchinstall --nokeepsrc"
	mkdir -p /home/app/.cache/paru/clone 2>/dev/null
	echo -e "[+] Build Tools PreInstallation"
	GITFLAGS="--filter=tree:0" paru -S --noconfirm --needed ${PARU_OPTS} cmake ninja clang nasm yasm rust cargo-c
	echo -e "[+] List of Packages Before Installing Dependency Apps:"
	echo -e "$(sudo pacman -Q | awk '{print $1}' | sed -z 's/\n/ /g;s/\s$/\n/g')" 2>/dev/null
	echo -e "[+] python-pip and tessdata PreInstallation for libjxl"
	GITFLAGS="--filter=tree:0" paru -S --noconfirm --needed ${PARU_OPTS} python-pip tesseract-data-eng tesseract-data-jpn
	( sudo pacman -Q | grep "tesseract-data-" | awk '{print $1}' | grep -v "osd\|eng\|jpn" | sudo pacman -Rdd - --noconfirm 2>/dev/null || true )
	echo -e "[+] highway-git Installation with makepkg"
	cd /home/app/.cache/paru/clone/ && paru --getpkgbuild highway-git
	sed -i -e "/build() {/a\    export CFLAGS+=' -Wno-unused-parameter -Wno-ignored-qualifiers' CXXFLAGS+=' -Wno-unused-parameter -Wno-ignored-qualifiers'" -e '/-Wno-dev/i\        -DHWY_ENABLE_TESTS:BOOL=OFF \\' highway-git/PKGBUILD
	cd ./highway-git && GITFLAGS="--filter=tree:0" paru -Ui --noconfirm --needed ${PARU_OPTS} --rebuild && cd ..
	echo -e "[+] libjxl-git Installation with pacman"
	cd /tmp && paru -S --noconfirm --needed ${PARU_OPTS} libjxl-metrics-git
	echo -e "[+] aom-av1-lavish-git Installation with makepkg"
	cd /home/app/.cache/paru/clone/ && paru --getpkgbuild aom-av1-lavish-git
	sed -i -e '/pkgver=/c\pkgver=33040.83500ccf3' -e '/pkgrel=/c\pkgrel=3' -e '/conflicts=/d' -e "/build() {/i\prepare() {\n  export CFLAGS+=' -Wno-unused-parameter -Wno-unused-variable -Wno-implicit-function-declaration -Wno-unused-result'\n  export CXXFLAGS+=' -Wno-unused-parameter -Wno-unused-variable -Wno-implicit-function-declaration -Wno-unused-result'\n  sed -i 's/-U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=0/-U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=2/g' \${pkgname%-git}/build/cmake/aom_configure.cmake\n}\n" aom-av1-lavish-git/PKGBUILD
	cd ./aom-av1-lavish-git && GITFLAGS="--filter=tree:0" paru -Ui --noconfirm --needed ${PARU_OPTS} --mflags="--force" --rebuild && cd ..
	echo -e "[+] ffmpeg and vapoursynth tools Installation with pacman"
	cd /tmp/ && paru -S --noconfirm --needed ${PARU_OPTS} ffmpeg vapoursynth ffms2 mkvtoolnix-cli vapoursynth-plugin-lsmashsource numactl
	sudo ldconfig 2>/dev/null
	echo -e "[-] Removing x265, svt-av1 & rav1e in order to install latest version"
	( sudo pacman -Rdd x265 svt-av1 rav1e --noconfirm 2>/dev/null || true )
	echo -e "[+] rav1e-git Installation with makepkg"
	cd /home/app/.cache/paru/clone/ && paru --getpkgbuild rav1e-git
	sed -i -e '/pkgver=/c\pkgver=0.6.4.r141.gc3b7754f' -e '/pkgrel=/c\pkgrel=3' -e '/conflicts=/d' -e "/cargo fetch/i\  sed -i 's|version = \"0.6.1\"|version = \"0.6.4\"|g' Cargo.toml" -e '/cargo fetch/c\  cargo fetch --target "x86_64-unknown-linux-gnu" && cargo update' -e '/cargo install/,/--path/c\  RUSTFLAGS="$RUSTFLAGS -C target-cpu=native" LDFLAGS+=" -lgit2" \\\n    cargo build --target "x86_64-unknown-linux-gnu" --release\n\n  strip "target/x86_64-unknown-linux-gnu/release/rav1e"\n  install -Dm755 "target/x86_64-unknown-linux-gnu/release/rav1e" -t "$pkgdir/usr/bin"\n' -e '/cargo cinstall/,/--prefix/c\  RUSTFLAGS="$RUSTFLAGS -C target-cpu=native" LDFLAGS+=" -lgit2" \\\n    cargo cinstall --target "x86_64-unknown-linux-gnu" --release --all-targets \\\n    --destdir "$pkgdir" --prefix "/usr"' rav1e-git/PKGBUILD
	cd ./rav1e-git && GITFLAGS="--filter=tree:0" paru -Ui --noconfirm --needed ${PARU_OPTS} --mflags="--force" --rebuild && cd ..
	sudo ldconfig 2>/dev/null
	echo -e "[+] x265-git Installation with makepkg"
	cd /home/app/.cache/paru/clone/ && paru --getpkgbuild x265-git
	sed -i -e '/pkgver=/c\pkgver=3.5.r101.g3dae0c3cc' -e '/pkgrel=/c\pkgrel=3' -e '/conflicts=/d' -e "/build() {/a\    export CFLAGS+=' -Wno-unused-parameter -Wno-unused-result' CXXFLAGS+=' -Wno-unused-parameter -Wno-unused-result'" -e '/-Wno-dev/i\        -DCMAKE_ASM_NASM_FLAGS=-w-macro-params-legacy \\' -e '/EXTRA_LINK_FLAGS/a\        -DENABLE_CLI=ON \\' -e "/build() {/i\prepare() {\n  sed -i 's|X265_BUILD 207|X265_BUILD 199|g' x265_git/source/CMakeLists.txt\n}\n" x265-git/PKGBUILD
	cd ./x265-git && GITFLAGS="--filter=tree:0" paru -Ui --noconfirm --needed ${PARU_OPTS} --mflags="--force" --rebuild && cd ..
	echo -e "[+] svt-av1-git Installation with makepkg"
	cd /home/app/.cache/paru/clone/ && paru --getpkgbuild svt-av1-git
	sed -i -e '/pkgver=/c\pkgver=1.5.0.r0.gea296ef3' -e '/pkgrel=/c\pkgrel=3' -e '/conflicts=/d' -e '/-DCMAKE_BUILD_TYPE:STRING/d' -e '/-DCMAKE_INSTALL_PREFIX:PATH/d' -e '/cmake -B build -S SVT-AV1/a        -DCMAKE_BUILD_TYPE=Release -DENABLE_AVX512=ON -DNATIVE=ON -DCMAKE_INSTALL_PREFIX=/usr -DBUILD_SHARED_LIBS=ON \\' svt-av1-git/PKGBUILD
	cd ./svt-av1-git && GITFLAGS="--filter=tree:0" paru -Ui --noconfirm --needed ${PARU_OPTS} --mflags="--force" --rebuild && cd ..
	echo -e "[i] ffmpeg version check"
	( ffmpeg -hide_banner -version || true )
	echo -e "[+] av1an-git Installation with makepkg"
	cd /home/app/.cache/paru/clone/ && paru --getpkgbuild av1an-git
	sed -i -e '/pkgver=/c\pkgver=r2282.14875b4' -e '/pkgrel=/c\pkgrel=3' -e '/conflicts=/d' -e '/cargo fetch/c\  cargo fetch --target "x86_64-unknown-linux-gnu" && cargo update' -e '/cargo build/c\  RUSTUP_TOOLCHAIN=stable RUSTFLAGS="$RUSTFLAGS -C target-cpu=native" \\\n    cargo build --target "x86_64-unknown-linux-gnu" --release\n\n  strip "target/x86_64-unknown-linux-gnu/release/av1an"' -e 's|target/release/av1an|target/x86_64-unknown-linux-gnu/release/av1an|g' av1an-git/PKGBUILD
	cd ./av1an-git && GITFLAGS="--filter=tree:0" paru -Ui --noconfirm --needed ${PARU_OPTS} --mflags="--force" --rebuild && cd ..
	echo -e "[i] av1an version check"
	( av1an --version || true )
	echo -e "[-] /tmp directory cleanup"
	cd /tmp && rm -rf -- *
	echo -e "[+] List of All Packages After Base Installation:"
	echo -e "$(sudo pacman -Q | awk '{print $1}' | sed -z 's/\n/ /g;s/\s$/\n/g')" 2>/dev/null
	echo -e "[>] PacCache Investigation"
	sudo du -sh /var/cache/pacman/pkg
	ls -lAog /var/cache/pacman/pkg/*.pkg.tar.zst 2>/dev/null
	echo -e "[+] Plugins Installation Block Starts Here"
	cd /tmp && CFLAGS+=' -Wno-unused-parameter -Wno-deprecated-declarations -Wno-unknown-pragmas -Wno-implicit-fallthrough' CXXFLAGS+=' -Wno-unused-parameter -Wno-deprecated-declarations -Wno-unknown-pragmas -Wno-implicit-fallthrough' paru -S --noconfirm --needed ${PARU_OPTS} vapoursynth-plugin-muvsfunc-git vapoursynth-plugin-mvsfunc-git vapoursynth-plugin-vsdeband-git vapoursynth-tools-getnative-git vapoursynth-plugin-vskernels-git vapoursynth-plugin-vsmasktools-git vapoursynth-plugin-vspyplugin-git vapoursynth-plugin-vsscale-git vapoursynth-plugin-vsutil-git vapoursynth-plugin-vstools-git vapoursynth-plugin-vsdenoise-git vapoursynth-plugin-neo_f3kdb-git
	libtool --finish /usr/lib/vapoursynth &>/dev/null
	echo -e "[i] Build vapoursynth-plugin-havsfunc-git with backdated commit sha"
	( yes | sudo pacman -Rdd vapoursynth-plugin-havsfunc 2>/dev/null || true )
	cd /home/app/.cache/paru/clone/ && paru --getpkgbuild vapoursynth-plugin-havsfunc-git
	sed -i '/pkgver() {/i\prepare() {\n  cd "${_plug}"\n  git reset --hard 7f0a9a7\n}\n' vapoursynth-plugin-havsfunc-git/PKGBUILD
	cd ./vapoursynth-plugin-havsfunc-git
	yes | CFLAGS="${CFLAGS} -Wno-unused-parameter -Wno-deprecated-declarations -Wno-unknown-pragmas -Wno-implicit-fallthrough" CXXFLAGS="${CXXFLAGS} -Wno-unused-parameter -Wno-deprecated-declarations -Wno-unknown-pragmas -Wno-implicit-fallthrough" paru -Ui --needed ${PARU_OPTS} --mflags="--noprogressbar --force" && cd ..
	libtool --finish /usr/lib/vapoursynth &>/dev/null
	sudo ldconfig 2>/dev/null
	echo -e "[>] PostPlugs PacCache Investigation"
	find /home/app/.cache/paru/clone/ -maxdepth 4 -iname *."pkg.tar.zst"* -type f | xargs -i sudo cp -vf {} /var/cache/pacman/pkg/
	sudo du -sh /var/cache/pacman/pkg
	ls -lAog /var/cache/pacman/pkg/*.pkg.tar.zst
	echo -e "[>] PostPlugs ParuCache Investigation"
	sudo du -sh /home/app/.cache/paru/* /home/app/.cache/paru/clone/*
	echo -e "[i] All Installed AppList:"
	echo -e "$(sudo pacman -Q | awk '{print $1}' | grep -v 'vapoursynth-' | sed -z 's/\n/ /g;s/\s$/\n/g')" 2>/dev/null
	echo -e "[i] All Installed Vapoursynth Plugins:"
	echo -e "$(sudo pacman -Q | awk '{print $1}' | grep 'vapoursynth-' | sed -z 's/\n/ /g;s/\s$/\n/g')" 2>/dev/null
	ls -lAog /usr/lib/vapoursynth/*.so 2>/dev/null
	echo -e "[i] Home directory Investigation"
	sudo du -sh ~/\.[a-z]* 2>/dev/null
	echo -e "[<] Cleanup"
	find "$(python -c "import os;print(os.path.dirname(os.__file__))")" -depth -type d -name __pycache__ -exec sudo rm -rf '{}' + 2>/dev/null
	( sudo pacman -Rdd cmake ninja clang nasm yasm rust cargo-c compiler-rt llvm-libs --noconfirm 2>/dev/null || true )
	sudo rm -rf /tmp/* /var/cache/pacman/pkg/* /home/app/.cache/yay/* /home/app/.cache/paru/* /home/app/.cargo/* 2>/dev/null
EOL

VOLUME ["/videos"]
WORKDIR /videos

ENTRYPOINT [ "/bin/bash" ]


# FROM base AS slim
#
# RUN <<-'EOL'
# 	( sudo rm -rf /var/cache/pacman/pkg/* /home/app/.cache/yay/* /home/app/.cache/paru/* /home/app/.cargo/* 2>/dev/null || true )
# EOL
#
# ENTRYPOINT [ "/bin/bash" ]

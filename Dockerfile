# syntax=docker/dockerfile:1.5
FROM archlinux:base-devel

# USER root

SHELL ["/bin/bash", "-c"]

# Add "app" user with "sudo" access
RUN <<-'EOL'
	pacman-key --init
	pacman-key --populate archlinux
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
	export PATH="/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin:/sbin:/bin"
	echo -e "[+] List of PreInstalled Packages:"
	echo -e "$(sudo pacman -Q | awk '{print $1}' | sed -z 's/\n/ /g;s/\s$/\n/g')" 2>/dev/null
	sudo pacman -Syu --noconfirm && sudo pacman -S --noconfirm --needed git pacman-contrib
	echo -e "[+] Installing yay-bin & paru-bin (pacman helpers)"
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
	paru -S --noconfirm --needed ${PARU_OPTS} cmake ninja clang nasm yasm rust cargo-c zip unzip p7zip
	echo -e "[+] List of Packages Before Installing Dependency Apps:"
	echo -e "$(sudo pacman -Q | awk '{print $1}' | sed -z 's/\n/ /g;s/\s$/\n/g')" 2>/dev/null
	export custPKGRoot="rokibhasansagar/46d764782ad15bbf546ad694cc820b45/raw/6c16c86b11403c3b7622dc3212514553cef7e8b6"
	echo -e "[+] python-pip and tessdata PreInstallation for libjxl"
	paru -S --noconfirm --needed ${PARU_OPTS} python-pip tesseract-data-eng tesseract-data-jpn
	( sudo pacman -Q | grep "tesseract-data-" | awk '{print $1}' | grep -v "osd\|eng\|jpn" | sudo pacman -Rdd - --noconfirm 2>/dev/null || true )
	echo -e "[+] highway-git Installation with makepkg"
	cd /home/app/.cache/paru/clone/ && paru --getpkgbuild highway-git
	sed -i -e "/build() {/a\    export CFLAGS+=' -Wno-unused-parameter -Wno-ignored-qualifiers' CXXFLAGS+=' -Wno-unused-parameter -Wno-ignored-qualifiers'" -e '/-Wno-dev/i\        -DHWY_ENABLE_TESTS:BOOL=OFF \\' highway-git/PKGBUILD
	cd ./highway-git && paru -Ui --noconfirm --needed ${PARU_OPTS} --rebuild && cd ..
	echo -e "[+] libjxl-metrics-git Installation with makepkg"
	paru -S --noconfirm --needed ${PARU_OPTS} libjxl-metrics-git
	( sudo pacman -Rdd aom --noconfirm 2>/dev/null || true )
	echo -e "[+] aom-av1-lavish-git Installation with makepkg"
	cd /home/app/.cache/paru/clone/ && mkdir -p aom-av1-lavish-git
	curl -sL "https://gist.github.com/${custPKGRoot}/aom-av1-lavish-git.PKGBUILD" >aom-av1-lavish-git/PKGBUILD
	cd ./aom-av1-lavish-git && paru -Ui --noconfirm --needed ${PARU_OPTS} --mflags="--force" --rebuild && cd ..
	echo -e "[+] vapoursynth-git, ffmpeg and other tools Installation with pacman"
	paru -S --noconfirm --needed ${PARU_OPTS} ffmpeg ffms2 mkvtoolnix-cli numactl
	sudo pacman -Rdd zimg --noconfirm 2>/dev/null
	cd /home/app/.cache/paru/clone/ && mkdir -p zimg-git
	curl -sL "https://aur.archlinux.org/cgit/aur.git/plain/PKGBUILD?h=zimg-git" | sed "/'zimg'/d" >zimg-git/PKGBUILD
	cd ./zimg-git && paru -Ui --noconfirm --needed ${PARU_OPTS} --rebuild && cd ..
	cd /home/app/.cache/paru/clone/ && git clone -q https://aur.archlinux.org/vapoursynth-git.git
	sed -i 's|vapoursynth/vapoursynth.git|vapoursynth/vapoursynth.git#commit=cac1a7a|g' vapoursynth-git/PKGBUILD
	cd ./vapoursynth-git && paru -Ui --noconfirm --needed ${PARU_OPTS} --rebuild && cd ..
	paru -S --noconfirm --needed ${PARU_OPTS} vapoursynth-plugin-lsmashsource-git
	sudo ldconfig 2>/dev/null
	libtool --finish /usr/lib &>/dev/null && libtool --finish /usr/lib/python3.11/site-packages &>/dev/null
	( vspipe --version || true )
	echo -e "[-] Removing x265, svt-av1 & rav1e in order to install latest version"
	( sudo pacman -Rdd x265 svt-av1 rav1e --noconfirm 2>/dev/null || true )
	echo -e "[+] rav1e-git Installation with makepkg"
	cd /home/app/.cache/paru/clone/ && mkdir -p rav1e-git
	curl -sL "https://gist.github.com/${custPKGRoot}/rav1e-git.PKGBUILD" >rav1e-git/PKGBUILD
	cd ./rav1e-git && paru -Ui --noconfirm --needed ${PARU_OPTS} --mflags="--force" --rebuild && cd ..
	sudo ldconfig 2>/dev/null
	echo -e "[+] x265-git Installation with makepkg"
	cd /home/app/.cache/paru/clone/ && mkdir -p x265-git
	curl -sL "https://gist.github.com/${custPKGRoot}/x265-git.PKGBUILD" >x265-git/PKGBUILD
	cd ./x265-git && paru -Ui --noconfirm --needed ${PARU_OPTS} --mflags="--force" --rebuild && cd ..
	echo -e "[+] svt-av1-git Installation with makepkg"
	cd /home/app/.cache/paru/clone/ && mkdir -p svt-av1-git
	curl -sL "https://gist.github.com/${custPKGRoot}/svt-av1-git.PKGBUILD" >svt-av1-git/PKGBUILD
	sed -i 's|gitlab.com/AOMediaCodec|github.com/BlueSwordM|g' svt-av1-git/PKGBUILD
	cd ./svt-av1-git && paru -Ui --noconfirm --needed ${PARU_OPTS} --mflags="--force" --rebuild && cd ..
	echo -e "[i] ffmpeg version check"
	( ffmpeg -hide_banner -version || true )
	echo -e "[-] /tmp directory cleanup"
	cd /tmp && rm -rf -- *
	echo -e "[+] List of All Packages After Base Installation:"
	echo -e "$(sudo pacman -Q | awk '{print $1}' | sed -z 's/\n/ /g;s/\s$/\n/g')" 2>/dev/null
	echo -e "[>] PacCache Investigation"
	sudo du -sh /var/cache/pacman/pkg
	ls -lAog /var/cache/pacman/pkg/*.pkg.tar.zst 2>/dev/null
	echo -e "[+] Plugins Installation Block Starts Here"
	cd /tmp && CFLAGS+=' -Wno-unused-parameter -Wno-deprecated-declarations -Wno-unknown-pragmas -Wno-implicit-fallthrough' CXXFLAGS+=' -Wno-unused-parameter -Wno-deprecated-declarations -Wno-unknown-pragmas -Wno-implicit-fallthrough' paru -S --noconfirm --needed ${PARU_OPTS} onetbb vapoursynth-plugin-muvsfunc-git vapoursynth-plugin-vstools-git vapoursynth-plugin-bestsource-git vapoursynth-plugin-imwri-git vapoursynth-plugin-vsdehalo-git vapoursynth-plugin-vsdeband-git vapoursynth-plugin-neo_f3kdb-git vapoursynth-plugin-neo_fft3dfilter-git vapoursynth-plugin-havsfunc-git vapoursynth-tools-getnative-git vapoursynth-plugin-vspyplugin-git vapoursynth-plugin-vsmasktools-git vapoursynth-plugin-bm3dcuda-cpu-git vapoursynth-plugin-knlmeanscl-git vapoursynth-plugin-nlm-git vapoursynth-plugin-retinex-git vapoursynth-plugin-eedi3m-git vapoursynth-plugin-znedi3-git vapoursynth-plugin-ttempsmooth-git vapoursynth-plugin-mvtools_sf-git
	( sudo pacman -Rdd vapoursynth-plugin-vsakarin-git --noconfirm 2>/dev/null || true )
	cd /home/app/.cache/paru/clone/ && paru --getpkgbuild vapoursynth-plugin-vsakarin-git
	sed -i -e '/prepare()/a\  sed -i "152,154d" ${_plug}/expr2/reactor/LLVMJIT.cpp && if grep -q "\-x86-asm-syntax=intel" ${_plug}/expr2/reactor/LLVMJIT.cpp; then echo "VSAkarin Patch Failed"; fi' vapoursynth-plugin-vsakarin-git/PKGBUILD
	cd ./vapoursynth-plugin-vsakarin-git && paru -Ui --noconfirm --needed ${PARU_OPTS} --mflags="--force" --rebuild && cd ..
	libtool --finish /usr/lib/vapoursynth &>/dev/null
	sudo ldconfig 2>/dev/null
	echo -e "[+] vapoursynth-plugin-{bmdegrain,wnnm}-git Installation with makepkg"
	export custPlugPKGRoot="rokibhasansagar/560defd34555c9f7652523377e96adff/raw/78562c0017473a75e283148e05b38b176853719d"
	cd /home/app/.cache/paru/clone/ && mkdir -p vapoursynth-plugin-bmdegrain-git
	curl -sL "https://gist.github.com/${custPlugPKGRoot}/vapoursynth-plugin-bmdegrain-git.PKGBUILD" >vapoursynth-plugin-bmdegrain-git/PKGBUILD
	cd ./vapoursynth-plugin-bmdegrain-git && paru -Ui --noconfirm --needed ${PARU_OPTS} --mflags="--force" --rebuild && cd ..
	cd /home/app/.cache/paru/clone/ && mkdir -p vapoursynth-plugin-wnnm-git
	curl -sL "https://gist.github.com/${custPlugPKGRoot}/vapoursynth-plugin-wnnm-git.PKGBUILD" >vapoursynth-plugin-wnnm-git/PKGBUILD
	cd ./vapoursynth-plugin-wnnm-git && paru -Ui --noconfirm --needed ${PARU_OPTS} --mflags="--force" --rebuild && cd ..
	libtool --finish /usr/lib/vapoursynth &>/dev/null
	sudo ldconfig 2>/dev/null
	echo -e "[+] av1an-git Installation with makepkg"
	cd /home/app/.cache/paru/clone/ && mkdir -p av1an-git
	curl -sL "https://gist.github.com/${custPKGRoot}/av1an-git.PKGBUILD" >av1an-git/PKGBUILD
	cd ./av1an-git && paru -Ui --noconfirm --needed ${PARU_OPTS} --mflags="--force" --rebuild && cd ..
	echo -e "[i] rAV1e and Av1an Investigation"
	rav1e --version
	av1an --version
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
	( sudo pacman -Rdd cmake ninja clang nasm yasm rust cargo-c compiler-rt --noconfirm 2>/dev/null || true )
	sudo rm -rf /tmp/* /var/cache/pacman/pkg/* /home/app/.cache/yay/* /home/app/.cache/paru/* /home/app/.cargo/* 2>/dev/null
EOL

VOLUME ["/videos"]
WORKDIR /videos

ENTRYPOINT [ "/usr/bin/bash" ]


# syntax=docker/dockerfile:1.5
FROM --platform=$BUILDPLATFORM archlinux:base-devel

ARG TARGETPLATFORM
ARG BUILDPLATFORM

# USER root

SHELL ["/bin/bash", "-c"]

# Add "app" user with "sudo" access
RUN <<-'EOL'
	pacman-key --init && pacman-key --populate archlinux
	useradd -G wheel -m -s /bin/bash app
	echo -e "\n%wheel ALL=(ALL:ALL) NOPASSWD: ALL\napp   ALL=(ALL:ALL) NOPASSWD: ALL\n" | sudo tee -a /etc/sudoers
EOL

USER app

WORKDIR /tmp

# Update pacman database and install yay and paru helpers
RUN <<-'EOL'
	set -ex
	( sudo pacman -Syu --noconfirm 2>/dev/null ) || true
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
	export PARU_OPTS="--skipreview --noprovides --useask --combinedupgrade --batchinstall --noinstalldebug --removemake --cleanafter --nokeepsrc"
	echo -e "[+] Build Tools PreInstallation"
	paru -S --noconfirm --needed ${PARU_OPTS} cmake ninja clang nasm yasm meson compiler-rt jq zig rust cargo-c libgit2 zip unzip p7zip python-pip doxygen python-sphinx
	export PARU_OPTS="--skipreview --noprovides --useask --combinedupgrade --batchinstall --noinstalldebug --removemake --nocleanafter --nokeepsrc"
	echo -e "[+] List of Packages Before Installing Dependency Apps:"
	echo -e "$(sudo pacman -Q | awk '{print $1}' | sed -z 's/\n/ /g;s/\s$/\n/g')" 2>/dev/null
	mkdir -p /home/app/.cache/paru/clone 2>/dev/null
	git clone --filter=blob:none https://github.com/rokibhasansagar/Arch_PKGBUILDs.git /home/app/.cache/paru/pkgbuilds/
	_custPKGBuilder() {
	  for pkg in "${pkgs[@]}"; do
	    echo -e "[+] ${pkg} Build+Installation with makepkg"
	    cd /home/app/.cache/paru/pkgbuilds/${pkg}/
	    ( git init -q || true )
	    ( paru -Ui --noconfirm --needed ${PARU_OPTS} --mflags="--force" --rebuild )
	  done
	}
	_uninstPKG() {
	  for pkg in "${unpkgs[@]}"; do
	    ( sudo pacman -Rdd ${pkg} --noconfirm 2>/dev/null ) || true
	  done
	}
	echo -e "[+] vapoursynth-git, ffmpeg and other tools Installation with pacman"
	export unpkgs=(zimg) && _uninstPKG
	export pkgs=({zimg,libdovi,libhdr10plus-rs}-git) && _custPKGBuilder
	paru -S --noconfirm --needed ${PARU_OPTS} ffmpeg ffms2 mkvtoolnix-cli numactl
	export unpkgs=(libjxl) && _uninstPKG
	export pkgs=(libjxl-metrics-git) && _custPKGBuilder
	export unpkgs=(vapoursynth aom) && _uninstPKG
	export pkgs=({aom-psy101,vapoursynth,foosynth-plugin-lsmashsource}-git) && _custPKGBuilder
	libtool --finish /usr/lib &>/dev/null
	libtool --finish /usr/lib/python3.12/site-packages &>/dev/null
	sudo ldconfig 2>/dev/null
	echo -e "[-] Removing x265, svt-av1 in order to install latest version"
	export unpkgs=(x265 svt-av1) && _uninstPKG
	sudo ldconfig 2>/dev/null
	export pkgs=({x265,svt-av1-psy}-git) && _custPKGBuilder
	echo -e "[+] List of All Packages After Base Installation:"
	echo -e "$(sudo pacman -Q | awk '{print $1}' | sed -z 's/\n/ /g;s/\s$/\n/g')" 2>/dev/null
	echo -e "[>] PacCache Investigation"
	sudo du -sh /var/cache/pacman/pkg /home/app/.cache/paru/*
	ls -lAog /var/cache/pacman/pkg/*.pkg.tar.zst 2>/dev/null
	echo -e "[+] Plugins Installation Block Starts Here"
	export pkgs=(waifu2x-ncnn-vulkan-git) && _custPKGBuilder
	( waifu2x-ncnn-vulkan || true )
	(
	  curl -sLO "https://avatars.githubusercontent.com/u/86638041?s=200&v=4"
	  waifu2x-ncnn-vulkan -i 86638041.png -o 86638041.2x.png -n 1 -s 2
	  ls -lAog 86638041*
	) || true
	( /usr/bin/onnx2ncnn --help || onnx2ncnn ) || true
	# llvm(17)-libs from Arch for vsakarin is needed now, so skip llvm16-libs
	export pkgs=(vapoursynth-plugin-{vsakarin,adjust}-git) && _custPKGBuilder
	export silentFlags='-Wno-unused-parameter -Wno-deprecated-declarations -Wno-unknown-pragmas -Wno-implicit-fallthrough'
	cd /tmp && CFLAGS+=" ${silentFlags}" CXXFLAGS+=" ${silentFlags}" paru -S --noconfirm --needed ${PARU_OPTS} onetbb vapoursynth-tools-getnative-git vapoursynth-plugin-{bestsource,bm3dcuda-cpu,eedi3m,havsfunc,imwri,kagefunc,knlmeanscl,muvsfunc,mvtools_sf,neo_f3kdb,neo_fft3dfilter,nlm,retinex,soifunc,ttempsmooth,vsdeband,vsdehalo,vsmasktools,vspyplugin,vstools,znedi3}-git
	libtool --finish /usr/lib/vapoursynth &>/dev/null
	sudo ldconfig 2>/dev/null
	export pkgs=(vapoursynth-plugin-{bmdegrain,wnnm,julek,ssimulacra2-zig}-git av1an-git) && _custPKGBuilder
	libtool --finish /usr/lib/vapoursynth &>/dev/null
	sudo ldconfig 2>/dev/null
	echo -e "[i] Encoder and Av1an Investigation"
	( ffmpeg -hide_banner -version || true )
	( x265 -V 2>&1 || true )
	( aomenc --help | grep "AOMedia Project AV1 Encoder" || true )
	( vspipe --version || true )
	( rav1e --version || true )
	( av1an --version || true )
	( SvtAv1EncApp --version || true )
	echo -e "[>] PostPlugs PacCache Investigation"
	find /tmp /home/app/.cache/paru/ -maxdepth 3 -type f -name "*.pkg.tar.zst" | xargs -i sudo cp -vf {} /var/cache/pacman/pkg/
	find /tmp /home/app/.cache/paru/ -maxdepth 3 -type f -name "*.pkg.tar.zst" | while read -r i; do curl -s -F"file=@${i}" https://temp.sh/upload && echo; done
	sudo du -sh /var/cache/pacman/pkg
	ls -lAog /home/app/.cache/paru/pkgbuilds/*/*.pkg.tar.zst /var/cache/pacman/pkg/*.pkg.tar.zst
	echo -e "[>] PostPlugs ParuCache Investigation"
	sudo du -sh /home/app/.cache/zig /home/app/.cache/paru/*/*
	echo -e "[i] All Installed AppList:"
	echo -e "$(sudo pacman -Q | awk '{print $1}' | grep -v 'vapoursynth-' | sed -z 's/\n/ /g;s/\s$/\n/g')" 2>/dev/null
	echo -e "[i] All Installed Vapoursynth Plugins:"
	echo -e "$(sudo pacman -Q | awk '{print $1}' | grep 'vapoursynth-' | sed -z 's/\n/ /g;s/\s$/\n/g')" 2>/dev/null
	ls -lAog /usr/lib/vapoursynth/*.so 2>/dev/null
	echo -e "[i] Home directory Investigation"
	sudo du -sh ~/\.[a-z]* 2>/dev/null
	echo -e "[<] Cleanup"
	find "$(python -c "import os;print(os.path.dirname(os.__file__))")" -depth -type d -name __pycache__ -exec sudo rm -rf '{}' + 2>/dev/null  # /usr/share/
	( sudo pacman -Rdd cmake ninja clang nasm yasm meson rust cargo-c compiler-rt zig --noconfirm 2>/dev/null || true )
	( paru -R --noconfirm ${PARU_OPTS} doxygen python-sphinx )
	sudo rm -rf /tmp/* /var/cache/pacman/pkg/* /home/app/.cache/zig/* /home/app/.cache/yay/* /home/app/.cache/paru/{clone,pkgbuilds}/* /home/app/.cargo/* 2>/dev/null
	echo -e "[+] List of All Packages At The End Of All Process:"
	echo -e "$(sudo pacman -Q | awk '{print $1}' | sed -z 's/\n/ /g;s/\s$/\n/g')" 2>/dev/null
EOL

VOLUME ["/videos"]
WORKDIR /videos

ENTRYPOINT [ "/usr/bin/bash" ]

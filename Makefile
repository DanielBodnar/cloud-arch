archlinux.raw: bootstrapped.raw build.sh
	./build.sh

config.iso: user-data meta-data
	pacman -Qi cdrtools >/dev/null || sudo pacman -S cdrtools # for genisoimage
	genisoimage  -output $@ -volid cidata -joliet -rock user-data meta-data

bootstrapped.raw: bootstrap.sh
	./bootstrap.sh

archlinux.instance.raw: archlinux.raw config.iso
	cp archlinux.raw $@

%.instance.img: %.img config.iso
	# depends on config.iso because some settings aren't applied unless the
	# image is clean
	cp $*.img $@

%.img: setups/%.sh archlinux.raw
	cp archlinux.raw $@.tmp
	sh -c 'set -e; D=$$(mktemp -d -t arch-cloud-setup.XXXXXXXXXX); ./mount.sh "$@.tmp" "$$D"; setups/$*.sh "$@.tmp" "$$D"; ./unmount.sh "$$D"'
	mv $@.tmp $@

.PRECIOUS: %.img
.PRECIOUS: %.instance.img

mount: archlinux.instance.raw
	mkdir -p mnt
	./mount.sh $< ./mnt

unmount:
	./unmount.sh

FWD=hostfwd=tcp::10080-:80
run-%: config.iso %.instance.img
	qemu-system-x86_64 \
		-m 1G \
		-enable-kvm \
		-nographic -drive file=$*.instance.img,if=virtio \
		-drive file=config.iso,if=virtio \
		-net user,hostfwd=tcp::10022-:22,$(FWD) \
		-net nic

run: config.iso archlinux.instance.raw
	qemu-system-x86_64 \
		-m 1G \
		-enable-kvm \
		-nographic -drive file=archlinux.instance.raw,if=virtio \
		-drive file=config.iso,if=virtio \
		-net user,hostfwd=tcp::10022-:22 -net nic

clean:
	rm -f bootstrapped.raw
	rm -f archlinux.raw
	rm -f *.tmp
	rm -f *.img
	rm -f config.iso

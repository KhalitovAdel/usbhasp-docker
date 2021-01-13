FROM ubuntu:bionic

ENV APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE=DontWarn
#probably need *-generic
ENV KERNEL_VERSION=4.15.0-99-generic
ARG DEBIAN_FRONTEND=noninteractive

COPY files/usb-vhci-hcd.patch files/usb-vhci-iocifc.patch /tmp/
COPY files/usbhaspd /etc/init.d/
COPY keys /home/keys

RUN dpkg --add-architecture i386; \
    apt-get update;

RUN apt-cache search linux-headers; \
    apt-get install -y linux-headers-$KERNEL_VERSION;

RUN apt-get install -y --no-install-recommends build-essential automake autoconf libtool libusb-0.1-4:i386 libjansson-dev kmod git;

WORKDIR /tmp

# ---- Clone vhci_hcd, libusb_vhci, UsbHasp from repositories ----------------------
RUN git clone git://git.code.sf.net/p/usb-vhci/vhci_hcd; \
    git clone git://git.code.sf.net/p/usb-vhci/libusb_vhci; \
    git -c http.sslVerify=false clone https://github.com/sam88651/UsbHasp.git;

#    # ---- Compile and install vhci_hcd ------------------------------------------------
RUN cd /tmp/vhci_hcd; \
    cp /tmp/vhci_hcd/usb-vhci.h /usr/include/linux; \
    patch usb-vhci-hcd.c /tmp/usb-vhci-hcd.patch; \
    patch usb-vhci-iocifc.c /tmp/usb-vhci-iocifc.patch; \
    make -e KVERSION=$KERNEL_VERSION; \
    cp usb-vhci-hcd.ko /lib/modules/$KERNEL_VERSION; \
    cp usb-vhci-iocifc.ko /lib/modules/$KERNEL_VERSION;

#    # ---- Compile and install libusb_vhci ---------------------------------------------
RUN cd /tmp/libusb_vhci; \
    autoreconf --install --force; \
    ./configure; \
    make -e KVERSION=$KERNEL_VERSION install;
    # ---- Compile and install UsbHasp -------------------------------------------------
RUN cd /tmp/UsbHasp; \
    make -e KVERSION=$KERNEL_VERSION; \
    cp /tmp/UsbHasp/dist/Release/GNU-Linux/usbhasp /usr/local/bin/; \
    ldconfig;
    # ---- Configure autoloading custom modules ----------------------------------------
RUN touch /etc/modules; \
    echo 'usb-vhci-hcd' >> /etc/modules; \
    echo 'usb-vhci-iocifc' >> /etc/modules; \
    touch /lib/modules/$KERNEL_VERSION/modules.dep; \
    echo 'usb-vhci-hcd.ko' >> /lib/modules/$KERNEL_VERSION/modules.dep; \
    echo 'usb-vhci-iocifc.ko' >> /lib/modules/$KERNEL_VERSION/modules.dep; \
    depmod -a;
#    # ---- Clear docker image ----------------------------------------------------------
#    apt-get remove --purge -y linux-headers-$(uname -r) build-essential automake autoconf libtool git; \
#    apt-get clean autoclean; \
#    apt-get autoremove -y; \
#    rm -rf /usr/include/linux; \
#    rm -rf /tmp/*; \
#    rm -rf /var/lib/apt/lists/*

CMD modprobe usb-vhci-iocifc; /etc/init.d/usbhaspd start; tail -f /dev/null
# Building the Toolchain #

The toolchain version does not necessarily need to coincide with the running firmware on your target iPhone. For example, 2.2 software can run on a 2.1 iPhone and 2.1 software can run on a 2.2.1 iPhone and so on (this is a very general statement; software relying on private frameworks or certain version-specific features may require an exact version). You may also use any new version of the SDK to build older versions of the toolchain, for instance the 2.2.1 SDK can still be used to build the 2.1 toolchain (just change TOOLCHAIN\_VERSION in the script).

All that being said, the instructions below indicate how to build a toolchain specific to each recent major iPhone firmware version.

## Toolchain for firmware 3.0 ##


### Before starting ###

We switched now to firmware 3.0. If you are interested in older firmwares see below.
The firmware 3.0 support is very fresh. If you have some troubles please leave
a comment or an issue.

We are busy and don't have much time to maintain the toolchain.sh script. If you
think you could help please drop a note.


### Checkout and get the files ###
First create a project directory and check out the latest copy of the toolchain builder. For Example:
```
mkdir -p ~/Projects/iphone/
cd ~/Projects/iphone/toolchain
svn checkout http://iphonedevonlinux.googlecode.com/svn/trunk/ ./
```

You will need to download the iPhone SDK 3.0 from Apple, which can be found here: http://developer.apple.com/iphone/ You can also choose to download the 3.0 or 3.0.1 firmware from Apple at this stage. If you do not, the script will download the firmware automatically (Firmare 3.0 iPhone(3G)).

You can now copy the SDK and Firmware (if you have it) to the toolchain builder's directory:
```
cd ~/Projects/iphone/toolchain
mkdir -p files/firmware
mv /path/to/iphone_sdk_3.0__leopard__9m2736__final.dmg files/
mv /path/to/iPhone1,2_3.0_7A341_Restore.ipsw files/firmware
```


### Packages needed to compile the toolchain ###

Before you start to build the firmware you need some packages installed on your system.
Building the toolchain with gcc-4.2 on my debian amd64 failed. I use gcc-4.3.

Here we provide a list of packages for Debian/Ubuntu

```
apt-get install \
  automake \
  bison \
  cpio \
  flex \
  g++ \
  g++-4.3 \
  g++-4.3-multilib \
  gawk \
  gcc-4.3 \
  git-core \
  gobjc-4.3 \
  gzip \
  libbz2-dev \
  libcurl4-openssl-dev \
  libssl-dev  \
  make \
  mount \
  subversion \
  sudo \
  tar \
  unzip \
  uuid \
  uuid-dev \
  wget \
  xar \
  zlib1g-dev \
```

If you are on 64 bit please install:
```
apt-get install g++-4.3-multilib gcc-4.3-multilib gobjc-4.3-multilib 
```

### Startup and build ###

Now the environment is set up, you can start the script with:
```
chmod u+x toolchain.sh
./toolchain.sh all
```

After all steps, the toolchain is in ./toolchain with the binaries in ./toolchain/pre/bin and the system in ./toolchain/sys/
After a rebuild you may get patch warnings/errors. Ignore them because
the build tries to patch already patched files.

With the newest version of the toolchain.sh script you can control the behaviour
and the filesystem places of the toolchain file with environment vars:
```
  BUILD_DIR:
    Build the binaries (gcc, otool etc.) in this dir.
    Default: $TOOLCHAIN/bld

  PREFIX:
    Create the ./bin ./lib dir for the toolchain executables
    under the prefix.
    Default: $TOOLCHAIN/pre

  SRC_DIR:
    Store the sources (gcc etc.) in this dir.
    Default: $TOOLCHAIN/src

  SYS_DIR:
    Put the toolchain sys files (the iphone root system) under this dir.
    Default: $TOOLCHAIN/sys

 example:

 sudo BUILD_DIR="/tmp/bld" SRC_DIR="/tmp/src" PREFIX="/usr/local" SYS_DIR=/usr/local/iphone_sdk_3.0 ./toolchain.sh all
```

## Toolchain for firmware 2.2 / 2.2.1 ##

The toolchain 2.2 is outdated. This is for historical reasons.

First create a project directory and check out the latest copy of the toolchain builder. For Example:
```
mkdir -p ~/Projects/iphone/
cd ~/Projects/iphone/toolchain
svn checkout http://iphonedevonlinux.googlecode.com/svn/branches/2.2 ./
```

You will need to download the iPhone SDK 2.2.1 from Apple, which can be found here: http://developer.apple.com/iphone/ You can also choose to download the 2.2.1 firmware from Apple at this stage. If you do not, the script will download the firmware automatically.

You can now copy the SDK and Firmware (if you have it) to the toolchain builder's directory:
```
cd ~/Projects/iphone/toolchain
mkdir -p files/firmware
mv /path/to/iphone_sdk_2.2.1_file files/
mv /path/to/firmware2.2.1_file files/firmware
```

Now the environment is set up, you can start the script with:
```
chmod u+x toolchain.sh
./toolchain.sh all
```

After all steps, the toolchain is in ./toolchain with the binaries in ./toolchain/pre/bin and the system in ./toolchain/sys/

## Toolchain for firmware 2.1 ##

Support also exists for firmware 2.1. You can build it in much the same way as the instructions for 2.2 above, with the only variation being in the first command block:
```
mkdir -p ~/Projects/iphone/
cd ~/Projects/iphone/toolchain
svn checkout http://iphonedevonlinux.googlecode.com/svn/branches/2.1/ ./
```

_Note: If you are supplying your own ipsw, it must be for firmware 2.1. However it is okay to use iPhone SDK 2.2, which can be downloaded from here: http://developer.apple.com/iphone/ as this still contains the required components._

# Testing the Toolchain #
In the subversion repository is a directory called "apps" which contains a test application you can build and deploy for the iPhone. Regardless of whether you built a 2.1, 2.2 or 3.0 toolchain, the instructions for testing are the same. You will need an iPhone connected to your local network to do this.

Navigate to the apps/HelloToolchain directory and run the following commands, noting that you must set "IP" to the address of your iPhone and change the path as appropriate:
```
cd ~/Projects/iphone/apps/HelloToolchain
IP=xxx.xxx.xxx.xxx PATH=../../toolchain/pre/bin/:$PATH make deploy
```

After running the above commands successfully, your iPhone should respring and you should see a HelloToolchain icon on the home screen. Run it and it should display "HelloToolchain" on the screen on a white background. This should indicate that the toolchain has successfully compiled an application for your iPhone. Happy coding!

# Manual Steps #
The instructions above recommend building the toolchain using the command:
```
./toolchain.sh all
```
This command encompasses all stages of building the toolchain. If for any reason you need to repeat a part of the process or perform it in components, you may call the script in other ways. For example, the "all" action is equivalent to running:
```
./toolchain.sh headers
./toolchain.sh firmware
./toolchain.sh darwin_sources
./toolchain.sh build
./toolchain.sh clean
```

A brief overview of the available actions and what they do, is available by running:
```
./toolchain.sh usage
```
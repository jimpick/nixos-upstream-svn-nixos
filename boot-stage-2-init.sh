#! @shell@

# !!! copied from stage 1; remove duplication

# Print a greeting.
echo
echo "<<< NixOS Stage 2 >>>"
echo

# Set the PATH.
export PATH=/empty
for i in @path@; do
    PATH=$PATH:$i/bin
    if test -e $i/sbin; then
        PATH=$PATH:$i/sbin
    fi
done

# Mount special file systems.
mount -t tmpfs none /etc -n # to shut up mount
touch /etc/fstab # idem
mount -t proc none /proc
mount -t sysfs none /sys
mount -t tmpfs none /dev
mount -t tmpfs none /tmp

# Create device nodes in /dev.
source @makeDevices@

# Start an interactive shell.
exec @shell@

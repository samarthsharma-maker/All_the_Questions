#!/bin/bash

BASE_DIR="/home/user"
cd "$BASE_DIR"

# Create report file
touch "${BASE_DIR}/zombie_report.txt"
chmod 777 "${BASE_DIR}/zombie_report.txt"

# Install dependencies
if ! command -v perl &>/dev/null; then
    apt-get update -qq
    apt-get install -y -qq perl
fi

# Task 1: Zombie Process Setup
# Bash automatically reaps children via its SIGCHLD handler so a true zombie
# cannot be created in pure bash. Perl's fork() does not reap, so the child
# stays in state Z. The script is named make_zombie so /proc shows that name.
cat > /tmp/make_zombie << 'EOF'
#!/usr/bin/perl
my $pid = fork();
if ($pid == 0) {
    exit 0;
} else {
    open(my $fh, ">", "/tmp/zombie_child_pid.txt");
    print $fh "$pid\n";
    close($fh);
    sleep(3600);
}
EOF
chmod +x /tmp/make_zombie

/tmp/make_zombie &
echo $! > /tmp/zombie_parent_pid.txt
sleep 1

echo "Setup complete."
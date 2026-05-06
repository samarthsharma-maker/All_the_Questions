# EFS Shared Filesystem: Fix the Driver Log System at VitalRoute Logistics

## Context

VitalRoute Logistics runs two delivery coordination servers that need to share a real-time driver activity log. When a driver completes a delivery both servers must be able to read and write to the same log file instantly. The team chose Amazon EFS as the shared filesystem since it can be mounted on multiple EC2 instances simultaneously.

The infra team set up the EFS filesystem and launched both servers. EFS was mounted on server-1 using the following commands:

```bash
sudo mount -a
df -h | grep efs
```

The fstab entry used on server-1 was:

```
<EFS-DNS>:/ /mnt/efs efs defaults,_netdev 0 0
```

However two bugs slipped through before end of shift:

**Bug 1:** The EFS security group allows port 2049 (NFS) from the entire VPC CIDR range instead of specifically from the EC2 security group. Mounting is currently failing on both servers.

**Bug 2:** The fstab entry for EFS is completely missing on server-2. Even after the security group is fixed, server-2 has no mount configuration and will remain disconnected from the shared filesystem.

Your job is to fix both issues and verify that a file written on server-1 is visible on server-2.

##### To save and exit vim: press `Ctrl + C`

---

## Getting Started

Run the setup script to provision the lab environment:

```bash
sudo bash /home/user/vitalroute-efs-lab/setup.sh
```

Sudo password: `user@123!`

Wait for setup to complete and note down the EFS DNS, server IPs, and key path printed in the terminal. Wait an additional 2-3 minutes before SSHing in.

---

## Environment Details

- **Region:** `us-west-2`
- **Mount point on both servers:** `/mnt/efs`
- **EC2 security group name:** `vitalroute-ec2-sg`
- **EFS security group name:** `vitalroute-efs-sg`
- **Server 1 instance name:** `vitalroute-server-1`
- **Server 2 instance name:** `vitalroute-server-2`
- **Key pair name:** `vitalroute-efs-key`
- **Key path:** `/home/user/vitalroute-efs-lab/vitalroute-efs-key.pem`
- **EFS DNS and instance IPs:** printed in terminal after setup

SSH into either server using:

```bash
ssh -i /home/user/vitalroute-efs-lab/vitalroute-efs-key.pem ec2-user@<SERVER-IP>
```

---

## Tasks

### Task 1: Fix the EFS Security Group

The EFS security group `vitalroute-efs-sg` currently allows port 2049 from the VPC CIDR. Fix it so that port 2049 is only allowed from the `vitalroute-ec2-sg` security group. This can be done from the AWS console or CLI — no SSH required.

### Task 2: Fix the Missing Mount on Server-2

SSH into `vitalroute-server-2` using the key pair above. Add the missing fstab entry using the same format used on server-1, mount the filesystem, and verify that the file written from server-1 is visible on server-2.

---

## Notes

- The security group fix takes effect immediately — no instance restart needed.
- Always use `sudo` when mounting or writing to `/mnt/efs` on Amazon Linux 2.
- Use `_netdev` in the fstab entry to ensure EFS is mounted after the network is available on boot.
- Use `us-west-2` for all resources.
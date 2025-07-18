# Chroot Security Environment

Đây là một hệ thống chroot bảo mật cho phép tạo môi trường cách ly an toàn với quản lý user và password.

## Tính năng

- ✅ Tự động cài đặt các dependencies cần thiết
- ✅ Tạo môi trường chroot hoàn chỉnh với các lệnh hệ thống cơ bản
- ✅ Quản lý user và password trong môi trường chroot
- ✅ Mount/unmount tự động các filesystem cần thiết
- ✅ Tích hợp systemd service để quản lý
- ✅ Interface menu thân thiện
- ✅ Logging chi tiết
- ✅ Bảo mật cao với quyền hạn hạn chế

## Yêu cầu hệ thống

- Ubuntu/Debian Linux
- Quyền root (sudo)
- Các package: `debootstrap`, `schroot` (sẽ được tự động cài đặt)

## Cài đặt và sử dụng

### 1. Chuẩn bị

```bash
# Clone hoặc tải về các file script
chmod +x setup_chroot.sh
chmod +x chroot_manager.sh
```

### 2. Sử dụng Menu Interactive (Khuyến nghị)

```bash
./chroot_manager.sh
```

Menu sẽ hiển thị các tùy chọn:
1. Cài đặt và thiết lập môi trường chroot mới
2. Đăng nhập vào môi trường chroot
3. Hiển thị trạng thái chroot
4. Tạo user bổ sung
5. Dọn dẹp môi trường chroot
6. Thoát

### 3. Sử dụng Command Line

#### Cài đặt môi trường chroot mới:
```bash
sudo ./setup_chroot.sh --install --user <username> --password <password>
```

#### Đăng nhập vào chroot:
```bash
sudo ./setup_chroot.sh --enter <username>
```

#### Kiểm tra trạng thái:
```bash
./setup_chroot.sh --status
```

#### Dọn dẹp:
```bash
sudo ./setup_chroot.sh --cleanup
```

## Cấu trúc môi trường chroot

Môi trường chroot được tạo tại `/opt/secure_chroot/` với cấu trúc:

```
/opt/secure_chroot/
├── bin/          # Các lệnh cơ bản (bash, ls, cat, etc.)
├── sbin/         # System binaries
├── usr/
│   ├── bin/      # User binaries
│   └── sbin/     # User system binaries
├── lib/          # Thư viện hệ thống
├── lib64/        # Thư viện 64-bit
├── etc/          # File cấu hình (passwd, group, shadow)
├── dev/          # Device files
├── proc/         # Process filesystem (mounted)
├── sys/          # System filesystem (mounted)
├── tmp/          # Temporary files
├── var/          # Variable data
└── home/         # User home directories
```

## Các lệnh có sẵn trong chroot

- **File operations**: `ls`, `cat`, `cp`, `mv`, `rm`, `mkdir`, `rmdir`
- **Permissions**: `chmod`, `chown`
- **Process**: `ps`
- **Text processing**: `grep`, `sed`, `awk`
- **Editors**: `nano`, `vi`
- **User management**: `whoami`, `id`, `passwd`, `su`
- **System**: `mount`, `umount`
- **Shell**: `bash`, `sh`

## Bảo mật

### Các biện pháp bảo mật đã triển khai:

1. **Cách ly filesystem**: Chroot tạo ra một root filesystem riêng biệt
2. **Hạn chế quyền truy cập**: User chỉ có quyền trong môi trường chroot
3. **Controlled binaries**: Chỉ copy các binary cần thiết và an toàn
4. **Separate user management**: Quản lý user riêng biệt trong chroot
5. **Mount isolation**: Filesystem được mount độc lập

### Lưu ý bảo mật:

- User trong chroot không thể truy cập filesystem bên ngoài
- Các process trong chroot bị hạn chế quyền
- Network access có thể bị hạn chế tùy cấu hình
- Không có quyền root trong chroot

## Troubleshooting

### 1. Lỗi "command not found" trong chroot
```bash
# Kiểm tra binary đã được copy chưa
ls /opt/secure_chroot/bin/
ls /opt/secure_chroot/usr/bin/

# Copy thêm binary nếu cần
sudo cp /usr/bin/command_name /opt/secure_chroot/usr/bin/
```

### 2. Lỗi library missing
```bash
# Kiểm tra dependencies của binary
ldd /path/to/binary

# Copy thư viện thiếu
sudo cp /path/to/library /opt/secure_chroot/lib/
```

### 3. Không mount được filesystem
```bash
# Kiểm tra mount points
mount | grep chroot

# Unmount và mount lại
sudo ./setup_chroot.sh --cleanup
sudo ./setup_chroot.sh --install
```

### 4. User không thể đăng nhập
```bash
# Kiểm tra user trong chroot
sudo cat /opt/secure_chroot/etc/passwd

# Kiểm tra permissions home directory
sudo ls -la /opt/secure_chroot/home/
```

## Log Files

Các hoạt động được ghi log tại:
- `/var/log/chroot_setup.log`

## Advanced Usage

### Thêm package vào chroot

```bash
# Vào chroot environment
sudo chroot /opt/secure_chroot /bin/bash

# Hoặc sử dụng debootstrap để cài package
sudo debootstrap --include=package_name stable /opt/secure_chroot
```

### Tạo script tự động

```bash
#!/bin/bash
# Auto setup script
sudo ./setup_chroot.sh --install --user autouser --password autopass123
echo "Chroot environment ready!"
```

## Uninstall

Để gỡ bỏ hoàn toàn:

```bash
sudo ./setup_chroot.sh --cleanup
sudo apt-get remove debootstrap schroot dchroot
```

## Support

Nếu gặp vấn đề, vui lòng:
1. Kiểm tra log file `/var/log/chroot_setup.log`
2. Đảm bảo đang chạy với quyền root
3. Kiểm tra disk space còn đủ không
4. Restart systemd service nếu cần

## License

MIT License - Sử dụng tự do cho mục đích học tập và thương mại.

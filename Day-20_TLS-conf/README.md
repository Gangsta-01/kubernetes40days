openssl genrsa -out admin.key 2048
openssl req -new -key admin.key -out admin.csr -subj "//CN=admin"  # double // for gitbash
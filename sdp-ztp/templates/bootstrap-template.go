package templates

//template for bootstrap
var BootstrapTmlp = `#!/bin/bash

cd /root/PnP
cat resolv.conf > /etc/resolvconf/resolv.conf.d/base
/etc/init.d/networking restart
chmod +x client
./client --registry_address="{{.IP}}" --pnp_server="NewPnPService" --pnp_op_type="installPackages" --server_cert_file "certs/server.crt"

`

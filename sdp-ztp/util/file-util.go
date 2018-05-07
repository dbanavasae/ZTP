package util

import (
	"fmt"
	"github.com/ZTP/sdp-ztp/templates"
	"os"
	"os/exec"
	"path/filepath"
	"text/template"
)

type Config struct {
	NetworkID    string
	NetMask      string
	IPRange      string
	BroadcastIP  string
	MatchboxPort string
	IP           string
	Interface	 string
}

func (config Config) GenerateTemplates() error {
	_, err := generateTemplate(config, templates.DnsmasqTmlp, "/etc/", "dnsmasq.conf")
	if err != nil {
		return err
	}
	_, err = generateTemplate(config, templates.PreseedTmlp, "/var/lib/matchbox/assets/coreos/client/", "preseed.cfg")
	if err != nil {
		return err
	}
	_, err = generateTemplate(config, templates.BootstrapTmlp, "/var/lib/matchbox/assets/coreos/client/", "bootstrap.sh")
	if err != nil {
		return err
	}
	_, err = generateTemplate(config, templates.GroupsTmlp, "/var/lib/matchbox/groups/", "ubuntu.json")
	if err != nil {
		return err
	}
	_, err = generateTemplate(config, templates.IgnitionTmlp, "/var/lib/matchbox/ignition/", "ubuntu-install-reboot.yaml")
	if err != nil {
		return err
	}
	_, err = generateTemplate(config, templates.ProfilesTmlp, "/var/lib/matchbox/profiles/", "ubuntu-install-reboot-client.json")
	if err != nil {
		return err
	}
	return nil
}

func generateTemplate(config Config, templateName string, dirPath string, fileName string) (string, error) {
	tmlp, err := template.New("template").Parse(templateName)
	if err != nil {
		fmt.Println("Error while generating dhcp templates, ", err)
		return "", err
	}
	file := filepath.Join(dirPath, fileName)
	if _, err := os.Stat(dirPath + "/" + fileName); err == nil {
		os.Remove(file)
	}
	f, err := os.OpenFile(file, os.O_WRONLY|os.O_CREATE|os.O_APPEND, 0600)
	if err != nil {
		return "", err
	}
	defer f.Close()
	tmlp.Execute(f, config)
	return f.Name(), nil
}

func DownloadArtifacts() error {
	fmt.Println("Downloading initrd.gz")
	err := executeCmd("rm -f /var/lib/matchbox/assets/coreos/client/initrd.g* && mkdir -p /var/lib/matchbox/assets/coreos/client && wget -P /var/lib/matchbox/assets/coreos/client http://archive.ubuntu.com/ubuntu/dists/xenial-updates/main/installer-amd64/current/images/netboot/ubuntu-installer/amd64/initrd.gz")
	if err != nil {
		return err
	}
	fmt.Println("Downloading linux")
	err = executeCmd("rm -f /var/lib/matchbox/assets/coreos/client/linux* && wget -P /var/lib/matchbox/assets/coreos/client http://archive.ubuntu.com/ubuntu/dists/xenial-updates/main/installer-amd64/current/images/netboot/ubuntu-installer/amd64/linux")
	if err != nil {
		return err
	}
	fmt.Println("Downloading undionly.kpxe")
	err = executeCmd("rm -f /var/lib/tftpboot/undionly.kpxe* && wget -P /var/lib/tftpboot/ http://boot.ipxe.org/undionly.kpxe")
	if err != nil {
		return err
	}
	return nil
}

func executeCmd(cmd string) error {
	command := exec.Command("/bin/sh", "-c", cmd)
	_, err := command.CombinedOutput()
	if err != nil {
		return err
	}
	return nil
}

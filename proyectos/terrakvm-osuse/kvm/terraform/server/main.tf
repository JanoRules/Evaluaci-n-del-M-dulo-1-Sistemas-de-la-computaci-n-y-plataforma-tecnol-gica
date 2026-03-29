#--- Volumen de Disco (Imagen Base de Rocky Linux 9)
resource "libvirt_volume" "os_image" {
  name   = "${var.hostname}-os_image"
  pool   = "pool"
  # Asegúrate de que el nombre del archivo coincida con el que descargaste
  source = "${var.path_to_image}/rocky9.qcow2" 
  format = "qcow2"
}

#--- Redimensionar el Disco 
resource "null_resource" "resize_volume" {
  provisioner "local-exec" {
    command = "sudo qemu-img resize ${libvirt_volume.os_image.id} ${var.diskSize}G"
  }
  depends_on = [libvirt_volume.os_image]
}

#--- Configuración de Usuario y SSH (Cloud-Init)
data "template_file" "user_data" {
  template = file("${path.module}/config/cloud_init.cfg") 
  vars = {
    hostname   = var.hostname
    fqdn       = "${var.hostname}.${var.domain}"
    public_key = file("${path.module}/key.pub") 
  }
}

resource "libvirt_cloudinit_disk" "commoninit" {
  name           = "${var.hostname}-commoninit.iso"
  pool           = "pool"
  user_data      = data.template_file.user_data.rendered
  network_config = file("${path.module}/config/network_config_dhcp.cfg")
}

#--- Definición de la Máquina Virtual (RAM, CPU y UEFI)
resource "libvirt_domain" "domain-server" {
  name   = var.hostname
  memory = var.memoryMB   # Definido en variables.tf (ej: 2048)
  vcpu   = var.cpu        # Definido en variables.tf (ej: 1)

  # --- FIX 1: Evitar el Kernel Panic pasando el CPU real del Host ---
  cpu {
    mode = "host-passthrough"
  }

  # --- SOPORTE UEFI ---
  firmware = "/usr/share/OVMF/OVMF_CODE_4M.fd"
  nvram {
    file     = "/var/lib/libvirt/qemu/nvram/${var.hostname}_VARS.fd"
    template = "/usr/share/OVMF/OVMF_VARS_4M.fd" 
  }

  # --- FIX 2: Usar bus SCSI para compatibilidad con Rocky 9 ---
  disk {
    volume_id = libvirt_volume.os_image.id
    scsi      = true
  }

  network_interface {
    network_name = "default"
  }

  cloudinit = libvirt_cloudinit_disk.commoninit.id

  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }

  graphics {
    type        = "spice"
    listen_type = "address"
    autoport    = true
  }
    # --- FIX 3: Transformación XSLT para forzar que el CD-ROM de Cloud-Init use SATA en lugar de IDE ---
    xml {
      xslt = <<-EOF
  <?xml version="1.0" ?>
  <xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
    <xsl:output omit-xml-declaration="yes" indent="yes"/>
    <xsl:template match="node()|@*">
      <xsl:copy>
        <xsl:apply-templates select="node()|@*"/>
      </xsl:copy>
    </xsl:template>

    <xsl:template match="/domain/devices/disk[@device='cdrom']/target/@bus">
      <xsl:attribute name="bus">
        <xsl:value-of select="'sata'"/>
      </xsl:attribute>
    </xsl:template>
  </xsl:stylesheet>
  EOF
    }

  depends_on = [null_resource.resize_volume]
}
# Para habilitar las redes

virsh net-define manage.xml
virsh net-start manage

virsh net-define privada.xml
virsh net-start privada


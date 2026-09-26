# -*- mode: ruby -*-
# vi: set ft=ruby :

# =============================================================================
# Laboratorio de APIs REST con MySQL sobre Ubuntu (Vagrant)
#
# Una sola VM contiene las 4 partes de la practica. El codigo fuente vive en
# el host (carpeta app/) y se copia adentro de la VM al aprovisionar.
#
#   app/parte1-memoria/   Flask + lista en RAM        (puerto 5000)
#   app/parte2-ubidots/   Cliente IoT -> Ubidots      (ningun puerto)
#   app/parte3-mysql/     Flask + MySQL               (puerto 5000)
#   app/desafio-node/     Node.js + Express + MySQL   (puerto 3000)
#
# Las partes 1 y 3 usan el mismo puerto, asi que no pueden correr a la vez.
# La 1 y la 3 SI pueden correr a la vez con el Desafio en Node.
#
# Uso:  vagrant up --provision
# =============================================================================

Vagrant.configure("2") do |config|

  if Vagrant.has_plugin? "vagrant-vbguest"
    config.vbguest.no_install  = true
    config.vbguest.auto_update = false
    config.vbguest.no_remote   = true
  end

  config.vm.define :servidorRest do |servidorRest|
    servidorRest.vm.box = "bento/ubuntu-22.04"
    servidorRest.vm.hostname = "servidorRest"
    servidorRest.vm.network :private_network, ip: "192.168.60.3"

    # Sin carpeta compartida: la VM se autoprovisiona desde app/.
    # Asi el resultado es identico a un `vagrant destroy` + `vagrant up`
    # limpio, y no hay confusion de "estoy editando /vagrant o /home/vagrant".
    servidorRest.vm.synced_folder ".", "/vagrant", disabled: true

    # --- Codigo fuente -------------------------------------------------------
    servidorRest.vm.provision "file",
      source: "app", destination: "/home/vagrant/"

    # Plantilla de variables de entorno (el token real NUNCA se sube al repo).
    servidorRest.vm.provision "file",
      source: ".env.example", destination: "/home/vagrant/practica.env.example"

    # --- Aprovisionamiento en orden -----------------------------------------
    servidorRest.vm.provision "shell", path: "provision/01-system-deps.sh"
    servidorRest.vm.provision "shell", path: "provision/02-mysql.sh"
    servidorRest.vm.provision "shell", path: "provision/03-python.sh"
    servidorRest.vm.provision "shell", path: "provision/04-node.sh"

    # Recordatorio util en cada `vagrant up`.
    servidorRest.vm.post_up_message = <<~MSG
      ------------------------------------------------------------
       Laboratorio listo. Entra con:   vagrant ssh servidorRest
       Codigo en la VM:                /home/vagrant/app
       Documentacion en el host:       docs/CHULETA-SUSTENTACION.md
      ------------------------------------------------------------
    MSG
  end
end

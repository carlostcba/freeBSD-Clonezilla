# Desplegar un Servidor Clonezilla PXE

Cree fácilmente un servidor Clonezilla PXE para restaurar imágenes a través de la red con la configuración mínima requerida.

## Características

- Instala los paquetes requeridos para que el servidor Clonezilla PXE funcione.
- Configura lo siguiente al implementar:
  - DHCP para arrendar direcciones IP a computadoras cliente que arrancan a través de la red.
  - NFS para que las computadoras cliente accedan a las imágenes de restauración a través de Clonezilla Live, Linux o FreeBSD.
  - Samba para acceder a las imágenes desde computadoras Windows.
  - Apache para que las computadoras cliente instalen sistemas operativos a través de la red.
- Crea un nuevo almacenamiento ZFS o importa uno existente para almacenar imágenes de sistemas operativos.
- Permite al usuario elegir el nombre de la cuenta de usuario administrador, la contraseña y el almacenamiento ZFS para las imágenes de sistemas operativos.
- Descarga e instala automáticamente la última versión de Clonezilla Live.
- Copia los archivos iPXE necesarios para arrancar las computadoras cliente a través de la red mediante BIOS o EFI.
- Crea un archivo de entrada de arranque de plantilla para las computadoras cliente que arrancan a través de la red, con la opción de realizar una copia de seguridad del disco o partición, y arrancar directamente a Clonezilla Live para copia de seguridad y restauración manual.

## Requisitos del Sistema

- Instalación de FreeBSD 12.1 o superior.
- Se recomiendan mínimo 4 GB de RAM.
- Escritorio o servidor con mínimo dos NIC instalados.
  - Se requiere un NIC dedicado para DHCP y PXE.
- Conexión a internet para descargar e instalar los paquetes requeridos.

## Instalación (por actualizar)

- Inicie sesión como root.
- Escriba `pkg install -y curl` para instalar curl y descargar los archivos de lanzamiento de implementación de Clonezilla.
- Escriba `curl -L -O https://github.com/alexmekic/pxe-server-deployment/releases/download/2.1.2/PXEDeploy2.1.2.zip` para descargar todos los archivos requeridos.
- Descomprima con `unzip PXEDeploy2.1.2.zip`.
- Escriba `chmod +x postinstall.sh` para permitir que se ejecute `postinstall.sh`.
- Escriba `./postinstall.sh` para ejecutar el archivo de script y siga las indicaciones.

## Historial de Versiones

- 1.0
  - Lanzamiento Inicial.
- 1.1
  - Actualizada la aplicación compilada de gestión pxe en el paquete con v1.2.
  - Agregado comando para establecer la reconstrucción automática de zpool pxe en `on` para la reconstrucción automática de ZFS.
- 2.0
  - Actualizada la aplicación compilada de gestión pxe en el paquete con v1.3.
  - Renovado el script para una mejor interactividad con el usuario.
    - Agregado mensaje de bienvenida al cargar el script.
  - Agregada la capacidad para que el usuario cree su propia cuenta de administrador.
  - Agregado nombre de la tarjeta de red para cada interfaz de red detectada para una mejor identificación al configurar IP.
  - Agregada función para que el usuario cree o importe un almacenamiento ZFS.
    - Agregada capacidad para mostrar una lista de discos disponibles y opciones de RAID aplicables.
  - Agregada instalación y configuración de apache para instalaciones de sistemas operativos a través de la red.
  - Permitir al usuario volver a ingresar la contraseña de Samba en caso de discrepancia.
  - Agregado subdirectorio `os` a la configuración de compartir Samba.
- 2.1
  - Aplicados permisos `chown` en el directorio `images` a `nobody:wheel` para mantener la funcionalidad de permisos con Clonezilla Live.
  - Redirigida la aplicación de Gestión PXE al subdirectorio `pxe_management` en el zfs pool.
  - Agregada entrada de arranque para arrancar Clonezilla para control manual.
  - Agregada capacidad para descargar la última aplicación de gestión de Python en `ClonezillaInstall.py`.
    - Redirigido el enlace de descarga para Clonezilla Live a Sourceforge para una velocidad de descarga más rápida.
    - Descargar la última versión de la aplicación de gestión de PXE.
  - Agregada opción para configuración de pool de almacenamiento ZFS de un solo disco.
  - 2.1.1
    - Cambiado `ip=frommedia` a `dhcp` en el archivo de arranque PXE para reflejar la corrección de errores en Clonezilla 2.7.
  - 2.1.2
    - Corregido error al crear la contraseña de Samba después de importar el pool ZFS.

# Nginx_openshift

- Creamos en nuestra máquina dónde tenemos nuestro repositorio git local, y en la ruta '/etc/secret-volume' 
un archivo llamado 'password' en el que incluiremos nuestra 'encrypt-key' para poder encriptar y desencriptar
los ejecutables '.jar' desde la carpeta 'latest_version' con los scripts 'decrypt' y 'encrypt'

```
sudo cd /etc
sudo mkdir secret-volume
cd secret-volume
sudo vi password
## METEMOS AQUÍ LA 'encrypt-key' ##
## 'INSERT', LA ESCRIBIMOS Y SALIMOS DANDO A 'ESC' Y ESCRIBIENDO ':wq' Y DANDO 'ENTER' ##
```

## CREATE OSH PROJECT

```
oc new-project clientes
```

## CREATE MYSQL DATABASE

Añadimos desde el catálogo a nuestro proyecto clientes una template de MySQL con los siguientes datos

- user: usuario
- pass: 1234
- root pass: 1234
- esquema: clientesdb

## APP DEPLOYMENT

### A) PRETASK

##### - CREATE SECRET FOR GITHUB

- Creamos una clave ssh en nuestra máquina con el siguiente comando

```
ssh-keygen 
```
- Damos enter a todo y dejamos el nombre como está ('id_rsa' e 'id_rsa.pub'), o si queremos lo podemos cambiar, eso no importa, pero si dejarlo sin passphrase, lo dejamos en blanco y damos enter

- Ahora vamos a nuestra cuenta de github y en settings añadimos la clave publica que acabamos de crear (id_rsa.pub)

- Creamos un secret de tipo source llamado github-user y seleccionamos ssh y pegamos nuestra clave publica generada en el paso anterior, y que es la misma que hemos incluido en los settings de nuestra cuenta de github

##### - CREATE SECRET FOR ENCRYPT-KEY

- Creamos un secret de tipo source llamado 'encrypt-key' de tipo básico y en el password obligatorio escribimos nuestra 'encrypt-key'

- Este secret llamado 'encrypt-key' la montará openshift en nuestro POD de la aplicación, en el archivo 'password' de la ruta 
'/etc/secret-volume' para poder desencriptar nuestro archivo ejecutable con la aplicación springboot cuando se despliegue y 
levante el POD con la aplicación

### B) DEPLOY

- Ejecutamos las templates que tenemos a continuación desde el directorio del repositorio de github que contiene 
dichas templates y que es 'GestionClientes_openshift_templates'

##### - CREATE WEBSERVER NGINX OPENSHIFT:

```
oc process -f build_webserver_template.yaml -p APPLICATION_NAME=nginx-gestion \
-p SOURCE_REPOSITORY_URL=https://github.com/JKGzenna/Nginx_openshift.git -p CONTEXT_DIR='1.0' \
-p APPLICATION_PORT_CLIENTES=8448 -p SOURCE_SECRET=github-user -p APPLICATION_TAG=v1.0 \
-p SOURCE_REPOSITORY_REF=master | oc apply -f-
```

##### - CREATE CLIENTESAPP OPENSHIFT:

```
oc process -f build_clientesapp_template.yaml -p APPLICATION_NAME=clientesapp \
-p SOURCE_REPOSITORY_URL=https://github.com/JKGzenna/GestionClientes_openshift.git \
-p CONTEXT_DIR='1.0-encrypt' -p SOURCE_SECRET=github-user -p APPLICATION_PORT=8081 \
-p NGINX_SERVICE_NAME=nginx-gestion -p NGINX_PORT=8448 \
-p SW_VERSION=spring-boot-jpa-1.0 -p HOSTNAME_HTTP= -p SOURCE_REPOSITORY_REF=create | oc apply -f-
```

### C) POST TASKS 

##### - ROUTE NO SSL

- Creamos también una ruta llamada clientesapp-nossl creada desde el servicio clientesapp y por el mismo puerto
que la aplicación de spring, en este caso 8081

##### - VOLUME FOR IMAGES OF CUSTOMERS

- Hacemos un primer build con la rama 'create' y accedemos a la aplicación y grabamos una imagen
en un perfil de un cliente entrando como 'admin' '12345'

- Creamos el storage para la carpeta 'update' y lo montamos en 
'/opt/clientesapp/uploads' y lo asociamos a la aplicación con el nombre 'uploads'

- Hacemos un segundo build con la rama 'update' y ya podemos acceder a la aplicación sin errores y podemos guardar
correctamente nuestras imágenes de clientes, ya que su hash va a la BBDD, pero la imagen va al servidor y al reiniciar el POD
esas imágenes del servidor se pierden

##### - EXTERNAL BBDD's

- Editamos el clientesapp deploymentconfig y añadimos las bases de datos que pudieran estar fuera del proyecto y que hicieran falta
```
    hostAliases:
     - hostnames:
         - DEV|PRE|PRO
       ip: { MYSQL_IP } # Nat IP 
```
##### - CONFIGMAPS
  
  - ConfigMaps allow you to decouple configuration artifacts from image content to keep containerized applications portable.
  This page provides a series of usage examples demonstrating how to create ConfigMaps and configure Pods using data stored in ConfigMaps.
 
  1) Create a ConfigMap from directories, specific files, or literal values:
  
   ```sh
     $ oc create configmap { SERVICE_NAME }-config --from-file=conf/
  ```
  
  2) Consuming ConfigMaps in Pods:
  
  ```sh
     $ oc volume dc/{ SERVICE_NAME } --overwrite --add -t configmap  \
       -m { PATH_CONFIGURATION }--name={ SERVICE_NAME }-config \
       --configmap-name={ SERVICE_NAME }-config 
  ```
  
##### - REQUIRED DEPLOYMENT VARIABLES 
+ DEPLOYMENT_USER:  github-user
+ PROXY: 	        n/a|url del proxy 
+ ENVIRONMENT:	    dev|pre|pro
+ SOFTWARE_VERSION: software version of the component 

##### - OTHER

- CLEAN WHORE APP

```sh 
for i in $(oc get all | grep -w "{ SERVICE_NAME }" | awk '{print $1}') ; do oc delete $i; done
```

- DELETE ALL ON A PROJECT

```sh 
oc delete all --all -n project
```
# To Instal Flask on Ubuntu
```
$ sudo apt-get install python3-pip
$ pip3 install Flask
$ pip3 freeze | grep Flask
```
 # To run the application
```
export FLASK_APP=apirest.py
export FLASK_ENV=development
python3 -m flask run --host=0.0.0.0
```

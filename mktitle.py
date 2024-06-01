#!/usr/bin/python3

import configparser
from sys import argv

config = configparser.ConfigParser()
config.read("titles.cfg")
with open("titles/"+argv[1]+".html", "w") as file:
    file.write(f'<title>{config["Titles"][argv[1]]} - LithosphereRocketry</title>')
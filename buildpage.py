#!/usr/bin/python3

import argparse
from lxml import html
from os import path

parser = argparse.ArgumentParser(
    prog='buildpage',
    description=('A slightly hacky program to generate static HTML pages from'\
                 'templates. Templates are included with a custom tag: '\
                 '<embed-file src=\'my-file.html\'></embed-file>')
)

parser.add_argument('-t', '--template',
    help='HTML template page to build on top of',
    dest='srcfile',
    type=str
)
parser.add_argument('-o', '--output',
    help='File to output data to',
    dest='dstfile',
    type=str
)
parser.add_argument('-p', '--search-path',
    help='Any number of paths to search for files within',
    dest='paths',
    action='append',
    nargs='*',
    type=str
)
parser.add_argument('-d', '--dependencies',
    help='Generates a list of dependencies instead of a complete file',
    dest='deponly',
    action='store_true'
)
parser.add_argument('-D', '--define',
    help='Replaces a specified filename with a specified different one',
    dest='defines',
    action='append',
    nargs=2,
    type=str
)
args = parser.parse_args()
# Flatten the list of paths
if args.paths == None:
    paths = ['.']
else:
    paths = [e for r in args.paths for e in r] + ['.']

tree = html.parse(args.srcfile)
if args.defines is None:
    defs = {}
else:
    defs = {name: value for [name, value] in args.defines}
mappings = {tag: tag.get('src') for tag in tree.iterfind('.//embed-file')}
defmappings = {tag: defs[name] if name in defs else name
               for tag, name in mappings.items()}
text = ''

def find_paths(paths, fname):
    for p in paths:
        if path.isfile(p + '/' + fname):
            return p + '/' + fname
    return None

def read_paths(paths, fname):
    realpath = find_paths(paths, fname)
    if realpath is None:
        return None
    else:
        f = open(realpath, 'r')
        s = f.read()
        f.close()
        return s


if args.deponly:
    text = '\n'.join(defmappings.values())
else:
    pathmaps = {p: read_paths(paths, p) for p in defmappings.values()}
    for tag, name in defmappings.items():
        if pathmaps[name] is None:
            print('File ' + name + ' not found')
            exit(-1)
        for frag in html.fragments_fromstring(pathmaps[name]):
            tag.addprevious(frag)
        tag.getparent().remove(tag)
    text = html.tostring(tree).decode()

if args.dstfile == None:
    print(text)
else:
    with open(args.dstfile, 'w') as out:
        out.write(text)
        out.close()
    
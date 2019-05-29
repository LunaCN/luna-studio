#!/usr/bin/env python3

import os
import distutils.dir_util
import fileinput
import glob
import subprocess
import shutil
import system as system

def prepare_holder(output, content_start, content_end, input1, input2, placeholder):
    with open(output, 'a+') as modified:
        modified.write(content_start)
        for infile in (input1, input2, placeholder):
            with open(infile, 'r') as f:
                shutil.copyfileobj(f, modified)
        modified.write(content_end)

def put_ghcjs(output, content, str_to_change):
    with open(content, 'r', encoding='utf8') as code:
        code = code.read()
        for line in fileinput.input(output, inplace=True):
            print(line.replace(str_to_change, code))

def prepare_ghcjs(output, placeholder, ghcjs):
    uuid = prep_path('../frontend/vendor/uuid.js')
    imports = prep_path('../frontend/vendor/imports.js')
    output_abs = prep_path(output)
    placeholder_abs = prep_path(placeholder)
    ghcjs_abs = prep_path(ghcjs)
    prepare_holder(output_abs, 'module.exports = (function(){', '});', uuid, imports, placeholder_abs)
    put_ghcjs(output_abs, ghcjs_abs, 'GHCJS_CODE_BE_THERE')

def prepare_css(output, styles_file):
    output_abs = prep_path(output)
    styles_abs = prep_path(styles_file)
    with open(output_abs, 'a+') as outfile:
        subprocess.Popen(['lessc', styles_abs], stdout=outfile)

def prep_path(path):
    script_abs_path = os.path.abspath(os.path.dirname(__file__))
    return os.path.normpath(os.path.join(script_abs_path, path))

# rename
def rm_old():
    try:
        os.remove(prep_path('../frontend/atom/styles/app.css'))
    except IOError:
        pass
    for path in ('../frontend/atom/lib/gen', '../frontend/atom/node_modules'):
        shutil.rmtree(prep_path(path), ignore_errors=True)

def create_dirs():
    for path in ('../frontend/atom/lib/gen', '../frontend/atom/styles', '../frontend/atom/styles'):
        os.makedirs(prep_path(path), exist_ok=True)

def ghcjs_code():
    node_editor = prep_path('../frontend/.stack-work/') + '/**/bin/node-editor.jsexe/all.js'
    text_editor = prep_path('../frontend/.stack-work/') + '/**/bin/text-editor.jsexe/all.js'
    node_editor_js = glob.glob(node_editor,recursive=True)
    text_editor_js = glob.glob(text_editor,recursive=True)
    prepare_ghcjs('../frontend/atom/lib/gen/node-editor-ghcjs.js', '../frontend/node-editor/env-node-editor.ghcjs', node_editor_js[0])
    prepare_ghcjs('../frontend/atom/lib/gen/text-editor-ghcjs.js', '../frontend/text-editor/env-text-editor.ghcjs', text_editor_js[0])

def cp_helper(input_path, output_path):
    distutils.dir_util.copy_tree(prep_path(input_path), prep_path(output_path))

def cp_files():
    cp_helper('../frontend/node-editor/js', '../frontend/atom/lib/gen')
    paths = [
        '../frontend/text-editor/js/atom-callback-text-editor.coffee',
        '../frontend/text-editor/js/app-text-editor.coffee',
        '../frontend/node-editor/config.release.js',
        '../frontend/node-editor/config.debug.js',
    ]
    for path in paths:
        shutil.copy(prep_path(path), prep_path('../frontend/atom/lib/gen'))

def run(dev_mode=False):
    if dev_mode:
        print('Preparing Luna Studio for installation')
        rm_old()
        create_dirs()
        ghcjs_code()
        cp_helper('../frontend/node-editor/assets/fonts', '../frontend/atom/styles/fonts')
        cp_helper('../frontend/node-editor/styles', '../frontend/atom/styles/gen')
        cp_files()


if __name__ == '__main__':
    run()

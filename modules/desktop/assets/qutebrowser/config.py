c.content.proxy = 'http://localhost:7890'
c.content.plugins = True
c.content.pdfjs = True
c.window.hide_decoration = True
c.editor.command = ['neovide', '--nofork', '{file}', '--', '-c', 'normal {line}G{column0}l']
c.url.searchengines = { 'DEFAULT': 'https://www.google.com/search?q={}'}
c.url.start_pages = 'https://google.com'
c.auto_save.session = True
c.session.lazy_restore = True
c.aliases['r'] = 'session-load'
c.hints.chars = 'fjdksla;rueiwoqpty'
c.hints.scatter = False
c.fonts.hints = 'bold default_size "JetBrains Mono"'
c.fonts.default_size = '8pt'
c.statusbar.show = 'in-mode' # 'always' # 'in-mode'
c.downloads.position = 'bottom'
#c.downloads.remove_finished = 5000
c.tabs.position = 'top' # 'left'

#c.hints.find_implementation = 'javascript'
c.hints.selectors['all'] += ['.icon'] # for argo
with config.pattern('*://*.infoq.cn/*') as p:
        p.hints.selectors['all'] += ['.close-geo']

c.fonts.web.family.standard= 'Noto Sans CJK SC'
c.fonts.web.family.fixed= 'JetBrains Mono'
c.fonts.web.family.sans_serif= 'Jetbrains Mono'
c.fonts.web.family.serif= 'Noto Serif CJK SC'

config.bind('<Alt-o>', 'edit-text')
config.bind('<Ctrl-o>', 'edit-url')
config.bind('zl', 'spawn --userscript rbw.nu')

config.bind(';l', 'hint userscript link translate.nu')
config.bind(';T', 'hint userscript all translate.nu --text')
config.bind('<Ctrl+T>', 'spawn --userscript translate.nu')


c.hints.selectors["code"] = [
    # Selects all code tags whose direct parent is not a pre tag
    ":not(pre) > code",
    "pre"
]
config.bind(';c', 'hint code userscript code_select.py')


config.load_autoconfig()

